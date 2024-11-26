#Installation du module Active Directory (si ça n'est pas déjà fait)
Install-WindowsFeature -Name RSAT-AD-PowerShell

# Le script doit intégrer une gestion d'erreur et une historisation de celle-ci dans un fichier dédié 
# Créer un fichier de log pour les erreurs
$logErrorFile = "C:\PerfLogs\error_log.txt"

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
$logFile = "C:\PerfLogs\user_creation_log.txt"

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

    # Importer les utilisateurs à créer   
    $csvFile = $env:CSV_FILE_PATH
    if (-not $env:CSV_FILE_PATH) {
        Write-ErrorLog -errorMessage "La variable d'environnement CSV_FILE_PATH n'est pas définie."
        return
    }
    $users = Import-Csv  -Path $csvFile -Delimiter '|'

    # Analyser les données
    $totalUser = $users.Count
    $userPerCountries = $users | Group-Object Country | Sort-Object Count -Descending
    $userPerPosition = $users | Group-Object Position | Sort-Object Count -Descending

    # Affichage des résultats
    Write-Host "Nombre total d'utilisateurs : $totalUser"
    $userPerCountries | ForEach-Object { 
        Write-Host "Pays : $($_.Name) --> Nombre d'utilisateurs : $($_.Count)" 
    }
    $userPerPosition | ForEach-Object {
        Write-Host "Poste : $($_.Name) --> Nombre : $($_.Count)"
    }

    # Créer l'OU racine si elle n'existe pas déjà
    # Créer l'OU racine si elle n'existe pas déjà
    $OUroot = Get-ADOrganizationalUnit -Filter { Name -eq "ScriptingLocal" } -ErrorAction SilentlyContinue
    if (-not $OUroot) {
        $OUroot = New-ADOrganizationalUnit -Name "ScriptingLocal" -ProtectedFromAccidentalDeletion $false -Path "DC=example,DC=com" -ErrorAction Stop
    }


    # Boucle pour créer les OUs pour les pays et les postes
    foreach ($country in $userPerCountries) {
        try {
            $countryOUPath = "OU=$($country.Name),$OUroot"

            # Créer l'OU du pays si elle n'existe pas
            if (-not (Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $countryOUPath })) {
                New-ADOrganizationalUnit -Name $country.Name -ProtectedFromAccidentalDeletion $false -Path $OUroot
            }

            foreach ($position in $userPerPosition) {
                $positionOUPath = "OU=$($position.Name),$countryOUPath"
                # Créer l'OU du poste si elle n'existe pas
                if (-not (Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $positionOUPath })) {
                    New-ADOrganizationalUnit -Name $position.Name -ProtectedFromAccidentalDeletion $false -Path $countryOUPath
                }
            }
        }
        catch {
            Write-ErrorLog -errorMessage "Erreur lors de la création de l'OU pour le pays $($country.Name) : $_"
        }
    }


    # Boucle pour créer les utilisateurs
    foreach ($user in $users) {
        $userid = "$($user.Name).$($user.ID)"
        $username = $user.Name
        $userposition = $user.Position
        $usercountry = $user.Country
        $OUPath = "OU=$userposition,OU=$usercountry,$OUroot"

        # Vérifier si l'utilisateur existe déjà
        $escapedUserId = $userid -replace "'", "''"
        if (Get-ADUser -Filter "SamAccountName -eq '$escapedUserId'" -ErrorAction SilentlyContinue) {
            continue # On passe à l'utilisateur suivant
        }

        try {
            if (Get-ADOrganizationalUnit -Filter { DistinguishedName -eq $OUPath }) {
                # Créer l'utilisateur
                $password = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force
                New-ADUser -Name $username `
                    -SamAccountName $userid `
                    -Surname "" `
                    -UserPrincipalName "$username@scripting.com" `
                    -Enabled $true `
                    -AccountPassword $password `
                    -Path $OUPath `
                    -ChangePasswordAtLogon $true

                $userCreated = Get-ADUser -SamAccountName $userid
                Write-UserLog -message "Utilisateur créé" -username $userCreated.Name -userid $userCreated.SamAccountName -distinguishedName $userCreated.DistinguishedName
            }
            else {
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
    param(
        [string]$samAccountName
    )
    try {
        $user = Get-ADUser -Filter { SamAccountName -eq $samAccountName }
        if ($user) {
            Disable-ADAccount -Identity $user.SamAccountName
            Write-UserLog -message "Utilisateur désactivé" -username $user.Name -userid $user.SamAccountName -distinguishedName $user.DistinguishedName
        }
        else {
            Write-ErrorLog -errorMessage "L'utilisateur $samAccountName n'existe pas"
        }
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
        2 {
            $samAccountName = Read-Host "Entrez le nom de l'utilisateur à désactiver"
            DesactiverUtilisateur -samAccountName $samAccountName
        }
        3 { SupprimerUtilisateur }
        4 { Get-Content $logFile }
        5 { Get-Content $logErrorFile }
        6 { break }
        default { Write-Host "Choix invalide" }
    }
} while ($choice -ne 6)