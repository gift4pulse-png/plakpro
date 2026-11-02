class PlateType {
  final int? id;
  final String nom;
  final double prix; // prix de vente HT (MAD)

  PlateType({this.id, required this.nom, required this.prix});

  Map<String, Object?> toMap() => {'id': id, 'nom': nom, 'prix': prix};

  factory PlateType.fromMap(Map<String, Object?> m) => PlateType(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        prix: (m['prix'] as num).toDouble(),
      );
}

class Client {
  final int? id;
  final String nom;
  final String telephone;
  final String ville;

  Client({this.id, required this.nom, this.telephone = '', this.ville = ''});

  Map<String, Object?> toMap() =>
      {'id': id, 'nom': nom, 'telephone': telephone, 'ville': ville};

  factory Client.fromMap(Map<String, Object?> m) => Client(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        telephone: (m['telephone'] as String?) ?? '',
        ville: (m['ville'] as String?) ?? '',
      );
}

class InvoiceLine {
  final int? id;
  final int? invoiceId;
  final int? plateTypeId;
  final String designation;
  final int quantite;
  final double prixUnitaire;

  InvoiceLine({
    this.id,
    this.invoiceId,
    this.plateTypeId,
    required this.designation,
    required this.quantite,
    required this.prixUnitaire,
  });

  double get total => quantite * prixUnitaire;

  Map<String, Object?> toMap() => {
        'id': id,
        'invoice_id': invoiceId,
        'plate_type_id': plateTypeId,
        'designation': designation,
        'quantite': quantite,
        'prix_unitaire': prixUnitaire,
      };

  factory InvoiceLine.fromMap(Map<String, Object?> m) => InvoiceLine(
        id: m['id'] as int?,
        invoiceId: m['invoice_id'] as int?,
        plateTypeId: m['plate_type_id'] as int?,
        designation: m['designation'] as String,
        quantite: m['quantite'] as int,
        prixUnitaire: (m['prix_unitaire'] as num).toDouble(),
      );
}

class Invoice {
  final int? id;
  final String numero;
  final DateTime date;
  final Client client;
  final double tauxTva; // en %, 0 si pas de TVA
  final List<InvoiceLine> lignes;

  Invoice({
    this.id,
    required this.numero,
    required this.date,
    required this.client,
    required this.tauxTva,
    required this.lignes,
  });

  double get totalHT => lignes.fold(0.0, (s, l) => s + l.total);
  double get montantTVA => totalHT * tauxTva / 100;
  double get totalTTC => totalHT + montantTVA;
}
