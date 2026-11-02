# Aluminum Ainaki — Android

Application Flutter hors ligne pour les clients, le catalogue historique et les factures, avec un nouveau module de distribution de marchandises en tournée.

## Fonctions existantes conservées

- Base SQLite historique `plaques_pro.db` et tables `clients`, `plate_types`, `invoices`, `invoice_lines` conservées.
- Facturation PDF et impression Bluetooth existantes.
- Recherche générale, catalogue et gestion des clients.
- Nom affiché sur Android : **Aluminum Ainaki**.

## Nouveau module Distribution

- Références de marchandises indépendantes du catalogue historique : nom, variante/dimension, prix d'achat, prix de vente et taille de paquet facultative.
- Taille de paquet personnalisable pour chaque référence (10, 20, autre valeur) ou vide si inconnue/variable.
- Réception au dépôt, chargement du camion et retour du camion au dépôt.
- Stock calculé séparément pour le dépôt et le camion, en pièces de base.
- Vente chez un client avec plusieurs références sur le même ticket.
- Quantités en paquets + pièces seules; les mouvements gardent les deux valeurs et le total en pièces.
- Paiement comptant, crédit, paiement partiel et virement en attente de confirmation.
- Historique des ventes, détails des articles et paiements, confirmation des virements et ajout de paiements ultérieurs.
- Interface des écrans principaux en français et en arabe avec sens RTL pour l'arabe; le choix est mémorisé localement.

## Migration de base de données

La version SQLite passe de 1 à 3 (migrations incrémentales). La migration ajoute uniquement les tables `distribution_products`, `distribution_sales`, `distribution_sale_lines`, `distribution_stock_moves`, `distribution_payments`, `distribution_expenses` et `app_settings`, plus leurs index. Elle ne supprime, ne renomme et ne réécrit aucune table historique.

Les anciennes références de catalogue ne sont pas automatiquement converties en produits de distribution : les produits et le stock initial doivent être enregistrés explicitement dans le module Distribution afin d'éviter d'inventer des quantités disponibles.

## Construire l'APK avec GitHub Actions

1. Envoyez le contenu du dossier du projet dans votre dépôt GitHub.
2. Vérifiez que `.github/workflows/build-android.yml` est présent.
3. Ouvrez **Actions** → **Aluminum Ainaki Android APK** → **Run workflow**.
4. Téléchargez l'artefact **Aluminum-Ainaki-release-APK** une fois l'exécution terminée.
5. Décompressez l'artefact pour obtenir `app-release.apk`.

Le workflow génère `android/` s'il manque, exécute `dart format`, les tests, `flutter analyze`, puis construit l'APK Release.

## Important avant mise à jour

Le nom de base reste `plaques_pro.db`. Pour installer par-dessus une version existante sans perdre ses données, l'APK doit avoir le même application ID et être signé avec le même certificat que l'ancienne version. Faites une sauvegarde avant toute mise à jour. Ne désinstallez pas l'ancienne application avant d'avoir vérifié la nouvelle.

## Vérifications restantes

Le code doit encore passer les tests et `flutter analyze` sur le runner GitHub. Les scénarios stock réel, ventes, confirmation de virement, PDF, Bluetooth, installation/mise à jour et affichage RTL doivent ensuite être vérifiés sur un téléphone réel. Les chiffres de stock ne sont corrects qu'après avoir saisi le stock initial réel au dépôt.
