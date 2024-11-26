#Installation du module Active Directory (si ça n'est pas déjà fait)
Install-WindowsFeature -Name RSAT-AD-PowerShell

# Le script doit intégrer une gestion d'erreur et une historisation de celle-ci dans un fichier dédié 
# Créer un fichier de log pour les erreurs
$logErrorFile = "C:\Logs\error_log.txt"

#Vérifier si le fichier de log existe
if (-not (Test-Path $logErrorFile)) {
    "Début du log d'erreur - $(Get-Date)" | Out-File -FilePath $logErrorFile
}

#Fonction pour ajouter les erreurs dans le log
function Write-ErrorLog {
    param (
        [string]$errorMessage
    )
    
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $errorMessage"
    $logMessage | Add-Content -Path $logErrorFile
}

#Créer un fichier de log pour les utilisateurs créés qui contient pour chaque utilisateur, son nom et son id, le distingueshName et la date de la création
$logFile = "C:\Logs\user_creation_log.txt"

#Vérifier si le fichier de log existe
if (-not (Test-Path $logFile)) {
    "Début du log de gestion d'utilisateur - $(Get-Date)" | Out-File -FilePath $logFile
}
#Fonction pour ajouter les users dans le log
function Write-UserLog {
    param (
        [string]$message,
        [string]$username,
        [string]$userid,
        [string]$distinguishedName
    )
    
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message Nom: $username, ID: $userid, DistinguishedName: $distinguishedName"
    $logMessage | Add-Content -Path $logFile
}

function CreationDepuisCSV {
    #Importer les utilisateurs à créer   
    $csvFile = Read-Host "Entrez le chemin du fichier csv"
    $users = Import-Csv  -Path $csvFile -Delimiter '|'

    #Analyser les données, le nombre d'utilisateurs, combien par pays, combien occupe tel ou tel poste etc. 
    $totalUser = $users.Count
    $userPerCountries = $users | Group-Object Country | Sort-Object Count -Descending
    $userPerPosition = $users | Group-Object Position | Sort-Object Count -Descending

    #Affichage des résultats
    Write-Host "Nombre total d'utilisateurs : $totalUser"
    $userPerCountries | ForEach-Object { 
        Write-Host "Pays : $($_.Name) --> Nombre d'utilisateurs : $($_.Count)" 
    }
    $userPerPosition | ForEach-Object {
        Write-Host "Poste : $($_.Name) --> Nombre : $($_.Count)"
    }

    #Créer un script qui permet de créer l'arborescence comme tel : une OU pour chaque pays et dans chaque pays créer une OU par poste
    #Racine de mon AD
    $basePath = "DC=scripting,DC=local" 

    #Boucle foreach qui parcour tous les pays
    foreach ($country in $userPerCountries) {
        try {
            #Chemin de l'OU du pays
            $countryOUPath = "OU=$($country.Name),$basePath"

            #Si l'OU du pays n'existe pas, on la crée
            if (-not (Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $countryOUPath })) {
                New-ADOrganizationalUnit -Name $country.Name -Path $basePath
            }        

            foreach ($position in $userPerPosition) {
                #Chemin de l'OU du poste
                $positionOUPath = "OU=$($position.Name),$countryOUPath"

                #Si l'OU du poste n'existe pas, on la crée
                if (-not (Get-ADOrganizationalUnit -Filter { Name -eq $position.Name })) {
                    New-ADOrganizationalUnit -Name $position.Name -Path $positionOUPath
                }
            }
        }
        catch {
            Write-ErrorLog -errorMessage "Erreur lors de la création de l'OU pour le pays $($country.Name) : $_"
        }


    }

    # Créer un second script permettant de peupler automatiquement les bonnes OU avec les bons utilisateurs, le script doit également 
    #Boucle qui parcour tous les utilisateurs
    foreach ($user in $users) {
        $userid = $user.Name + "." + $user.ID
        $username = $user.Name
        $userposition = $user.Position
        $usercountry = $user.Country
        $OUPath = "OU=$userposition,OU=$usercountry,$basePath"

        #Vérifier si l'utilisateur existe déjà
        if (Get-ADUser -Filter "SamAccountName -eq '$userid'" -ErrorAction SilentlyContinue) {
            continue #On passe à l'utilisateur suivant
        }

        try {
            if (Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $OUPath }) {
                New-ADUser -Name "$username" `
                    -SamAccountName $userid `
                    -Surname "" `
                    -UserPrincipalName "$username@scripting.com" `
                    -Enabled $true `
                    -AccountPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) `
                    -Path $OUPath
                    -ChangePasswordAtLogon $true

                    $user = Get-ADUser -SamAccountName $userid
                    write-UserLog -message "Utilisateur créé" -username $user.Name -userid $user.SamAccountName -distinguishedName $user.DistinguishedName

            } else {
                Write-ErrorLog -errorMessage "L'OU $OUPath n'existe pas pour l'utilisateur $username."
            }
        }
        catch {
            Write-ErrorLog -errorMessage "Erreur lors de la création de l'utilisateur $username : $_"
        }

    }

}


#Bonus 1 : Créer un script qui permet de désactiver un utilisateur
function DesactiverUtilisateur {
    $samAccountName = Read-Host "Entrez le SamAccountName de l'utilisateur à désactiver"
    try {
        $user = Get-ADUser -Filter { SamAccountName -eq $samAccountName }
        if($user){
            Disable-ADAccount -Identity $user.SamAccountName
            Write-UserLog -message "Utilisateur désactivé" -username $user.Name -userid $user.SamAccountName -distinguishedName $user.DistinguishedName
        } else {
            Write-ErrorLog -errorMessage "L'utilisateur $samAccountName n'existe pas"
        }
       
    catch {
        Write-ErrorLog -errorMessage "Erreur lors de la désactivation de l'utilisateur $samAccountName : $_"
    }
}

#Bonus 2 : Créer un script qui permet de supprimer un utilisateur qui sont désactivés depuis plus de 90 jours
function SupprimerUtilisateur {
    $date = (Get-Date).AddDays(-90)
    $usersToDelete = Get-ADUser -Filter { Enabled -eq $false -and whenChanged -lt $date } -Properties whenChanged

    foreach ($user in $usersToDelete) {
        try {
            Remove-ADUser -Identity $user.SamAccountName -Confirm:$false
            Write-UserLog -message "Utilisateur supprimé" -username $user.Name -userid $user.SamAccountName -distinguishedName $user.DistinguishedName
        }
        catch {
            Write-ErrorLog -errorMessage "Erreur lors de la suppression de l'utilisateur $($user.SamAccountName) : $_"
        }
    }
}

#Bonus 3 : Transformer le rendu du TP en un outil simple à utiliser par un utilisateur lambda
do {
    Write-Host "1. Créer les utilisateurs depuis le fichier csv"
    Write-Host "2. Désactiver un utilisateur"
    Write-Host "3. Supprimer les utilisateurs désactivés depuis plus de 90 jours"
    Write-Host "4. Consulter le fichier de gestion des utilisateurs"
    Write-Host "5. Consulter le fichier de gesiton des erreurs"
    Write-Host "6. Quitter"
    $choice = Read-Host "Faites votre choix"

    switch ($choice) {
        1 { CreationDepuisCSV }
        2 { DesactiverUtilisateur }
        3 { SupprimerUtilisateur }
        4 { Get-Content $logFile }
        5 { Get-Content $logErrorFile }
        6 { break }
        default { Write-Host "Choix invalide" }
    }
} while ($choice -ne 6)