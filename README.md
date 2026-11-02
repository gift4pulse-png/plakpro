# Aluminum Ainaki — Android

Application Flutter hors ligne pour la gestion des clients, du catalogue de plaques et des factures.

## Modifications incluses

- Thème rouge Aluminum Ainaki et symbole de requin dessiné dans l'application.
- Recherche générale : clients, téléphone, ville, types de plaques, numéros de facture et désignations de lignes.
- Recherche locale dans les écrans Clients, Catalogue et Historique.
- Actualisation automatique des écrans après chaque ajout, modification ou suppression.
- Navigation avec `IndexedStack` pour conserver les écrans actifs.
- Saisie directe des quantités au clavier (ex. 100, 300, 1200), en gardant les boutons +/-.
- Les données restent dans la base SQLite existante `plaques_pro.db`; aucun changement de schéma n'est effectué.
- Nom affiché sur Android : **Aluminum Ainaki**.

## Construire l'APK avec GitHub Actions

1. Envoyez le contenu du dossier du projet dans votre dépôt GitHub.
2. Vérifiez que `.github/workflows/build-android.yml` est présent.
3. Ouvrez l'onglet **Actions**.
4. Choisissez **Aluminum Ainaki Android APK** puis **Run workflow**.
5. Quand l'exécution est terminée, ouvrez-la et téléchargez l'artefact **Aluminum-Ainaki-release-APK**.
6. Décompressez l'artefact téléchargé : il contient `app-release.apk`.

Le workflow génère le dossier `android/` s'il manque, configure le nom affiché et les permissions Bluetooth, lance les tests et construit l'APK.

## Important pour les données déjà présentes

La base SQLite est conservée et son nom reste `plaques_pro.db`. Le workflow garde également l'identifiant Android utilisé par la version précédente (`ma.plaques.plaques_pro_copy`) pour faciliter une mise à jour. Pour qu'Android accepte une mise à jour par-dessus l'application installée, l'APK doit aussi être signé avec le même certificat que l'ancienne version. Sauvegardez les données importantes avant toute réinstallation; ne désinstallez pas l'ancienne application avant d'avoir vérifié la nouvelle.

## Vérifications

Le workflow exécute les tests unitaires de calcul des factures, l'analyse Dart (non bloquante pour les avertissements existants) et la compilation APK Release. Les fonctions Bluetooth, PDF et l'installation/mise à jour doivent encore être vérifiées sur un téléphone et avec l'imprimante réelle.
