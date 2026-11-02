# Plaques Pro — Application Android (Flutter) pour distributeur de plaques d'immatriculation

Interface 100 % française · hors-ligne (SQLite) · PDF + WhatsApp · impression thermique Bluetooth.

## 1. Choix technique

| Option | Verdict |
|---|---|
| **Flutter + SQLite (sqflite)** | **Recommandé** : une seule base de code, UI rapide, bons paquets PDF et Bluetooth, fonctionne sans internet |
| React Native | Possible, mais l'écosystème Bluetooth thermique est moins stable |
| Android natif (Kotlin) | Plus de contrôle, mais développement plus long |
| Firebase | Inutile au départ (usage local). À ajouter plus tard pour la sauvegarde cloud |

## 2. Schéma de la base de données

```
plate_types(id PK, nom, prix)
clients(id PK, nom, telephone, ville)
invoices(id PK, numero UNIQUE, date, client_id FK→clients, taux_tva)
invoice_lines(id PK, invoice_id FK→invoices ON DELETE CASCADE,
              plate_type_id, designation, quantite, prix_unitaire)
```

Le prix et la désignation sont **copiés dans la ligne de facture** : modifier le catalogue plus tard ne change pas les anciennes factures.

Totaux : `HT = Σ qté × prix` · `TVA = HT × taux / 100` · `TTC = HT + TVA`.

## 3. Structure du projet

```
lib/
  main.dart                  navigation (4 onglets)
  models/models.dart         PlateType, Client, Invoice, InvoiceLine
  db/app_database.dart       SQLite + CRUD + numérotation F2026-0001
  services/pdf_service.dart  PDF A5 + partage (WhatsApp)
  services/thermal_service.dart  ticket ESC/POS 58/80 mm
  screens/                   facture, historique, catalogue, clients
```

## 4. Mise en route

```bash
flutter create --org ma.plaques --project-name plaques_pro .   # génère le dossier android/
flutter pub get
flutter run
```

Après `flutter create`, dans `android/app/build.gradle` : `minSdkVersion 21` (ou `flutter.minSdkVersion`).

Dans `android/app/src/main/AndroidManifest.xml`, avant `<application>` :

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>
```

Appairez d'abord l'imprimante thermique dans Réglages Android → Bluetooth.

## 5. Roadmap

1. **Semaine 1** — Base : projet, SQLite, catalogue des plaques, clients. *(fait dans ce code)*
2. **Semaine 2** — Facture : sélection client, quantités, calcul HT/TVA/TTC, numérotation. *(fait)*
3. **Semaine 3** — Export PDF + partage WhatsApp ; impression Bluetooth. *(fait, à tester sur votre imprimante)*
4. **Semaine 4** — Finitions : nom/adresse/ICE de la société sur la facture, logo, recherche clients, suppression/annulation de facture.
5. **Ensuite** — Gestion de stock réel (entrées/sorties), suivi des paiements (crédit client), statistiques, sauvegarde cloud, icône et publication.

## 6. Points à vérifier

- **Accents** : beaucoup d'imprimantes thermiques bon marché n'affichent pas les accents ; le code les retire sur le ticket. Si la vôtre supporte le codepage CP1252/CP858, vous pouvez le retirer.
- **Mentions légales** : la facture marocaine doit en général comporter l'ICE, l'IF, le RC et l'adresse de la société. Ajoutez-les dans `pdf_service.dart` (paramètre `societe`).
- **Imprimante** : testez le 58 mm vs 80 mm (`PaperSize` dans `thermal_service.dart`).
