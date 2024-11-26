#Installation du module Active Directory (si ça n'est pas déjà fait)
Install-WindowsFeature -Name RSAT-AD-PowerShell


#Importer les utilisateurs à créer   
$csvFile = "C:\Users\MarcAWAD\Downloads\users.csv"
$users = Import-Csv -Path $csvFile -Delimiter '|'
Write-Host("Importation réussite.")

#Analyser les données, le nombre d'utilisateurs, combien par pays, combien occupe tel ou tel poste etc. 
$totalUser = $users.Count
$userPerCountries = $users | Group-Object Country | Sort-Object Count -Descending
$userPerPosition = $users | Group-Object Position | Sort-Object Count -Descending

#Affichage des résultats
Write-Host "Nombre total d'utilisateurs : $totalUser"
$userPerCountries | ForEach-Object { 
    Write-Host "Pays: $($_.Name), Nombre d'utilisateurs: $($_.Count)" 
}
$userPerPosition | ForEach-Object {
    Write-Host "Poste: $($_.Name), Nombre: $($_.Count)"
}


#Créer un script qui permet de créer l'arborescence comme tel : une OU pour chaque pays et dans chaque pays créer une OU par poste
#Racine de mon AD
$basePath = "DC=scripting,DC=local" 

#Boucle foreach qui parcour tous les pays
foreach($country in $userPerCountries) {

    #Chemin de l'OU du pays
    $countryOUPath = "OU=$($country.Name),$basePath"

    #Si l'OU du pays n'existe pas, on la crée
    if(-not (Get-ADOrganizationalUnit -Filter {Name -eq $country.Name})) {
        New-ADOrganizationalUnit -Name $country.Name -Path $basePath
    }

    foreach($position in $userPerPosition) {
        #Chemin de l'OU du poste
        $positionOUPath = "OU=$($position.Name),$countryOUPath"

        #Si l'OU du poste n'existe pas, on la crée
        if(-not (Get-ADOrganizationalUnit -Filter {Name -eq $position.Name})) {
            New-ADOrganizationalUnit -Name $position.Name -Path $positionOUPath
        }
    }
}


# Créer un second script permettant de peupler automatiquement les bonnes OU avec les bons utilisateurs, le script doit également 
#Boucle qui parcour tous les utilisateurs
foreach ($user in $users) {
    $userid = $user.ID
    $username = $user.Name
    $userposition = $user.Position
    $usercountry = $user.Country
    $OUPath =  "OU=$userposition,OU=$usercountry,$basePath"

    if()
}

## créer un fichier de log 
## qui contient pour chaque utilisateur, son nom et son id, le distingueshName et la date de la création

## Le script doit intégrer une gestion d'erreur et une historisation de celle-ci dans un fichier dédié 

## Commenter de façon claire le script

$OUroot = New-ADOrganizationalUnit -Name test -ProtectedFromAccidentalDeletion $false -ErrorAction Stop

## lister les ou de ton dossier 
Get-ADOrganizationalUnit -filter * | Where-Object {$_.distinguishedName -like "*OU=j.jebane,OU=TP,DC=ps,DC=domain*"}

## bonus
## Créer une fonction pour désactiver des utilisateurs
## Créer une fonction pour supprimer les utilisateurs désactivés depuis plus de 90 jours
## transformer le rendu du TP en un outil simple à utiliser par un utilisateur lambda