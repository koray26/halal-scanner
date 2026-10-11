"""Erzeugt lib/domain/knowledge/pubchem_data.dart aus der PubChem-PUG-REST-API.

Aufruf (aus dem Projektordner):  python tool/fetch_pubchem.py

- Fragt je Stoff den vollständigen englischen Namen ab und speichert CID, IUPAC-Name, Summenformel und die
  erste CAS-Nummer aus der Synonymliste.
- Hält das PubChem-Limit ein (höchstens 5 Anfragen pro Sekunde).
- Findet PubChem keinen eindeutigen Stoff (z. B. Gemische wie E471), wird
  nichts eingetragen – es wird nichts geraten.

Die Daten beschreiben nur die allgemeine Stoffidentität. Sie sagen nichts über
die Herkunft eines Stoffes oder sein Vorkommen in einem bestimmten Produkt.
"""

import datetime
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://pubchem.ncbi.nlm.nih.gov/rest/pug"
UA = "HalalScanner-build (https://github.com/koray26/halal-scanner)"
CAS = re.compile(r"^\d{2,7}-\d{2}-\d$")

# Muss zu lib/domain/knowledge/substances.dart (Liste `additives`) passen.
ADDITIVES = {
    "120": "Carmine", "422": "Glycerol", "428": "Gelatine",
    "430": "Polyoxyethylene (8) stearate", "431": "Polyoxyethylene (40) stearate",
    "432": "Polysorbate 20", "433": "Polysorbate 80", "434": "Polysorbate 40",
    "435": "Polysorbate 60", "436": "Polysorbate 65", "441": "Gelatine",
    "470a": "Sodium, potassium and calcium salts of fatty acids",
    "470b": "Magnesium salts of fatty acids",
    "471": "Mono- and diglycerides of fatty acids",
    "472a": "Acetic acid esters of mono- and diglycerides of fatty acids",
    "472b": "Lactic acid esters of mono- and diglycerides of fatty acids",
    "472c": "Citric acid esters of mono- and diglycerides of fatty acids",
    "472d": "Tartaric acid esters of mono- and diglycerides of fatty acids",
    "472e": "Mono- and diacetyl tartaric acid esters of mono- and diglycerides of fatty acids",
    "472f": "Mixed acetic and tartaric acid esters of mono- and diglycerides of fatty acids",
    "473": "Sucrose esters of fatty acids", "474": "Sucroglycerides",
    "475": "Polyglycerol esters of fatty acids", "477": "Propane-1,2-diol esters of fatty acids",
    "478": "Lactylated fatty acid esters", "481": "Sodium stearoyl-2-lactylate",
    "482": "Calcium stearoyl-2-lactylate", "483": "Stearyl tartrate",
    "491": "Sorbitan monostearate", "492": "Sorbitan tristearate",
    "493": "Sorbitan monolaurate", "494": "Sorbitan monooleate",
    "495": "Sorbitan monopalmitate", "542": "Bone phosphate", "570": "Fatty acids",
    "572": "Magnesium stearate", "627": "Disodium guanylate", "631": "Disodium inosinate",
    "635": "Disodium 5'-ribonucleotides", "904": "Shellac", "920": "L-cysteine",
    "921": "L-cystine",
}

# Alkohole und verwandte Stoffe, die NICHT mit Trinkalkohol gleichzusetzen sind
# (außer Ethanol selbst) – für die Unterscheidung in der App.
SUBSTANCES = {
    "ethanol": "Ethanol",
    "cetyl_alcohol": "Cetyl alcohol",
    "stearyl_alcohol": "Stearyl alcohol",
    "benzyl_alcohol": "Benzyl alcohol",
    "sorbitol": "Sorbitol",
    "propylene_glycol": "Propylene glycol",
    "acetic_acid": "Acetic acid",
}


def get(path, attempts=5):
    req = urllib.request.Request(f"{BASE}/{path}", headers={"User-Agent": UA})
    for i in range(attempts):
        time.sleep(0.5 + i * 3)  # deutlich unter 5 Anfragen/Sekunde; bei "busy" länger warten
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if e.code != 503 or i == attempts - 1:
                raise


def lookup(name):
    q = urllib.parse.quote(name)
    props = get(f"compound/name/{q}/property/IUPACName,MolecularFormula/JSON")
    if not props:
        return None
    rows = props["PropertyTable"]["Properties"]
    if len(rows) != 1:  # mehrdeutig -> nichts eintragen
        return None
    row = rows[0]
    syn = get(f"compound/cid/{row['CID']}/synonyms/JSON") or {}
    synonyms = (syn.get("InformationList", {}).get("Information") or [{}])[0].get("Synonym", [])
    cas = next((s for s in synonyms if CAS.match(s)), None)
    return {
        "query": name,
        "cid": row["CID"],
        "iupac": row.get("IUPACName"),
        "formula": row.get("MolecularFormula"),
        "cas": cas,
    }


def dart_str(v):
    if v is None:
        return "null"
    return "'" + v.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def entry(key, r):
    return (f"  {dart_str(key)}: PubChemRecord(query: {dart_str(r['query'])}, cid: {r['cid']}, "
            f"iupacName: {dart_str(r['iupac'])}, formula: {dart_str(r['formula'])}, "
            f"cas: {dart_str(r['cas'])}),")


def main():
    today = datetime.date.today().isoformat()
    additives, missing = {}, []
    for number, name in ADDITIVES.items():
        # Nur der vollständige Name: Über E-Nummern liefert PubChem bei Gemischen
        # (z. B. E471, Polysorbate) eine einzelne Beispielstruktur.
        r = lookup(name)
        if r:
            additives[number] = r
        else:
            missing.append(f"E{number}")
    substances = {k: r for k, n in SUBSTANCES.items() if (r := lookup(n))}

    lines = [
        "// Automatisch erzeugt von tool/fetch_pubchem.py – nicht von Hand ändern.",
        f"// Abruf: {today}. Quelle: PubChem (NCBI), https://pubchem.ncbi.nlm.nih.gov/",
        "//",
        "// Allgemeine Stoffidentität – KEIN Nachweis von Herkunft oder Vorkommen",
        "// eines Stoffes in einem bestimmten Produkt.",
        f"// Ohne eindeutigen PubChem-Eintrag (Gemische o. Ä.): {', '.join(missing) or '-'}",
        "",
        "class PubChemRecord {",
        "  const PubChemRecord({required this.query, required this.cid, this.iupacName, this.formula, this.cas});",
        "",
        "  /// Suchbegriff, mit dem der Eintrag gefunden wurde.",
        "  final String query;",
        "  final int cid;",
        "  final String? iupacName;",
        "  final String? formula;",
        "",
        "  /// Erste CAS-Nummer aus den PubChem-Synonymen (von Einsendern gemeldet).",
        "  final String? cas;",
        "",
        "  String get url => 'https://pubchem.ncbi.nlm.nih.gov/compound/$cid';",
        "}",
        "",
        f"const pubchemRetrievedAt = '{today}';",
        "",
        "/// Schlüssel: E-Nummer ohne „E“ (wie `Additive.number`).",
        "const Map<String, PubChemRecord> pubchemByAdditive = {",
        *[entry(k, r) for k, r in additives.items()],
        "};",
        "",
        "/// Weitere Stoffe zur Unterscheidung von Ethanol und anderen Alkoholen.",
        "const Map<String, PubChemRecord> pubchemSubstances = {",
        *[entry(k, r) for k, r in substances.items()],
        "};",
        "",
    ]
    with open("lib/domain/knowledge/pubchem_data.dart", "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"{len(additives)} Zusatzstoffe, {len(substances)} weitere Stoffe; ohne Eintrag: {missing}")


if __name__ == "__main__":
    main()
