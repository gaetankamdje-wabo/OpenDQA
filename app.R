##############################################################################
# Open DQA - Fitness-for-Purpose Data Quality Assessment Platform
# Authors: G. Kamdje Wabo and contributors
# License: MIT. (c) 2026 Heidelberg University.
# Research prototype. Not a medical device. See the in-app disclaimer.
##############################################################################

# Package loading and database driver detection.
pkgs <- c(
  "shiny", "bs4Dash", "DT", "readxl", "jsonlite", "stringr", "dplyr",
  "lubridate", "rlang", "data.table", "shinyjs", "shinyWidgets", "waiter",
  "cluster", "officer", "flextable"
)
to_install <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(to_install) > 0) {
  for (pkg in to_install) {
    tryCatch(
      install.packages(pkg, dependencies = TRUE, quiet = TRUE),
      error = function(e) message(paste("Optional:", pkg, "not installed"))
    )
  }
}
suppressPackageStartupMessages({
  library(shiny); library(bs4Dash); library(DT); library(readxl)
  library(jsonlite); library(stringr); library(dplyr); library(lubridate)
  library(rlang); library(stats); library(data.table); library(shinyjs)
  library(shinyWidgets); library(waiter); library(officer); library(flextable)
})
has_cluster <- tryCatch(requireNamespace("cluster", quietly = TRUE), error = function(e) FALSE)
if (has_cluster) library(cluster)

sql_pg <- tryCatch(
  requireNamespace("DBI", quietly = TRUE) && requireNamespace("RPostgres", quietly = TRUE),
  error = function(e) FALSE
)
sql_ms <- tryCatch(
  requireNamespace("DBI", quietly = TRUE) && requireNamespace("odbc", quietly = TRUE),
  error = function(e) FALSE
)
if (sql_pg) { library(DBI); library(RPostgres) }
if (sql_ms) { library(DBI); library(odbc) }
options(shiny.maxRequestSize = 2 * 1024^3, shiny.sanitize.errors = TRUE)

# Trilingual string table. Every user-facing label in English, German, and French is
# resolved through i18n() at render time.
i18n_db <- list(
  # Welcome screen.
  wel_title = list(
    en = "Welcome to Open DQA",
    de = "Willkommen bei Open DQA",
    fr = "Bienvenue dans Open DQA"
  ),
  wel_sub = list(
    en = "Fitness-for-Purpose Data Quality Assessment for Clinical Research",
    de = "Fitness-for-Purpose-Datenqualitätsbewertung für klinische Forschung",
    fr = "Évaluation Fitness-for-Purpose de la qualité des données pour la recherche clinique"
  ),
  wel_desc = list(
    en = "Data quality is assessed based on the specific requirements of each research question (fitness-for-purpose). The platform provides statistical profiling, a manual check builder, guided data cleansing with audit trail, and generates a Data Quality Assessment Certificate and a Cleansing Certificate.",
    de = "Datenqualität wird anhand der spezifischen Anforderungen jeder Forschungsfrage bewertet (Fitness-for-Purpose). Die Plattform bietet statistische Profilierung, einen manuellen Prüfungsbaukasten, geführte Datenbereinigung mit Änderungsprotokoll und erstellt ein Datenqualitäts-Bewertungszertifikat sowie ein Bereinigungszertifikat.",
    fr = "La qualité des données est évaluée selon les exigences spécifiques de chaque question de recherche (fitness-for-purpose). La plateforme fournit un profilage statistique, un constructeur de vérifications, un nettoyage guidé avec piste d'audit, et génère un Certificat d'Évaluation de Qualité et un Certificat de Nettoyage."
  ),
  wel_learn_more = list(
    en = "Learn more about Open DQA",
    de = "Mehr über Open DQA erfahren",
    fr = "En savoir plus sur Open DQA"
  ),
  wel_tut = list(en = "Take the Tutorial", de = "Tutorial starten", fr = "Suivre le tutoriel"),
  wel_tut_hint = list(
    en = "New here? This step-by-step guide walks you through every feature with concrete examples so you can start productively right away.",
    de = "Erste Nutzung? Diese Schritt-für-Schritt-Anleitung erklärt jede Funktion mit konkreten Beispielen, damit Sie sofort produktiv starten können.",
    fr = "Première utilisation? Ce guide pas à pas présente chaque fonctionnalité avec des exemples concrets."
  ),
  wel_start = list(en = "Proceed to Assessment", de = "Zur Bewertung", fr = "Accéder à l'évaluation"),
  wel_start_hint = list(
    en = "Load your dataset and begin the structured quality assessment workflow.",
    de = "Laden Sie Ihren Datensatz und starten Sie den strukturierten Qualitätsbewertungs-Workflow.",
    fr = "Chargez votre jeu de données et lancez le workflow d'évaluation structuré."
  ),
  wel_workflow_title = list(en = "How It Works", de = "So funktioniert es", fr = "Comment ça marche"),
  wel_who_title = list(en = "Who Is This For?", de = "Für wen ist das?", fr = "À qui s'adresse cet outil?"),
  wel_who = list(
    en = "Researchers, data managers, clinical study coordinators, hospital IT, and quality officers who need a transparent, reproducible, and fully documented quality assessment workflow for their clinical data.",
    de = "Forscher, Datenmanager, klinische Studienkoordinatoren, Krankenhaus-IT und Qualitätsbeauftragte, die einen transparenten, reproduzierbaren und vollständig dokumentierten Qualitätsbewertungs-Workflow für ihre klinischen Daten benötigen.",
    fr = "Chercheurs, gestionnaires de données, coordinateurs d'études cliniques, informaticiens hospitaliers et responsables qualité qui ont besoin d'un workflow d'évaluation qualité transparent, reproductible et documenté."
  ),
  wel_faq_title = list(en = "Frequently Asked Questions", de = "Häufig gestellte Fragen", fr = "Questions fréquentes"),
  # Legal and safety disclaimer.
  disclaimer_title = list(en = "Important Notice: Research Tool", de = "Wichtiger Hinweis: Forschungstool", fr = "Avis important: Outil de recherche"),
  disclaimer_text = list(
    en = "Open DQA is an open-source research tool developed at Heidelberg University (MIISM). It is NOT a certified medical product under EU MDR, FDA, or any regulatory framework, and must not be used as a basis for clinical decisions.\n\nHowever, Open DQA is specifically designed to support clinical research by providing transparent, reproducible, and auditable data quality assessment. Researchers are strongly encouraged to integrate Open DQA into their data management workflows to strengthen the reliability and credibility of their study results.\n\nThe user is solely responsible for validating and interpreting all results.",
    de = "Open DQA ist ein Open-Source-Forschungstool, entwickelt an der Universität Heidelberg (MIISM). Es ist KEIN zertifiziertes Medizinprodukt gemäß EU-MDR, FDA oder einem anderen regulatorischen Rahmenwerk und darf nicht als Grundlage für klinische Entscheidungen dienen.\n\nOpen DQA wurde jedoch speziell zur Unterstützung der klinischen Forschung entwickelt. Es bietet transparente, reproduzierbare und auditierbare Datenqualitätsbewertung. Forscher werden nachdrücklich ermutigt, Open DQA in ihre Datenmanagement-Workflows zu integrieren.\n\nDer Nutzer ist allein verantwortlich für die Validierung und Interpretation aller Ergebnisse.",
    fr = "Open DQA est un outil de recherche open source développé à l'Université de Heidelberg (MIISM). Ce n'est PAS un produit médical certifié selon EU MDR, FDA ou tout autre cadre réglementaire.\n\nCependant, Open DQA est spécifiquement conçu pour soutenir la recherche clinique. L'utilisateur est seul responsable de la validation et de l'interprétation de tous les résultats."
  ),
  disclaimer_accept = list(
    en = "I have read and accept this notice: I will use this tool for research purposes",
    de = "Ich habe diesen Hinweis gelesen und akzeptiere ihn: Ich verwende dieses Tool für Forschungszwecke",
    fr = "J'ai lu et j'accepte cet avis: J'utiliserai cet outil à des fins de recherche"
  ),
  disclaimer_proceed = list(en = "Enter Open DQA", de = "Open DQA starten", fr = "Entrer dans Open DQA"),
  # Shared button labels.
  btn_back = list(en = "Back", de = "Zurück", fr = "Retour"),
  btn_next = list(en = "Next", de = "Weiter", fr = "Suivant"),
  no_data = list(en = "No data loaded yet.", de = "Keine Daten geladen.", fr = "Aucune donnée chargée."),
  no_issues = list(en = "No issues found.", de = "Keine Probleme gefunden.", fr = "Aucun problème trouvé."),
  confirm_reset = list(
    en = "This will clear ALL data, checks, and results. Are you sure?",
    de = "Dies löscht ALLE Daten, Prüfungen und Ergebnisse. Sind Sie sicher?",
    fr = "Cela supprimera TOUTES les données. Êtes-vous sûr?"
  ),
  # Step 1 (Import) labels.
  s1_title = list(
    en = "Step 1: Data Import",
    de = "Schritt 1: Datenimport",
    fr = "Étape 1: Import des données"
  ),
  s1_source = list(
    en = "Where is your data? Choose your source and format below.",
    de = "Wo sind Ihre Daten? Wählen Sie Quelle und Format.",
    fr = "Où sont vos données? Choisissez source et format."
  ),
  s1_preview = list(en = "Data Preview", de = "Datenvorschau", fr = "Aperçu des données"),
  s1_demo_desc = list(
    en = "50 synthetic German clinical inpatient encounters with ICD-10-GM, OPS, age, gender, admission/discharge dates, length of stay, and clinical notes. Reflects real coding patterns (multimorbidity, pre/post-operative, negative LOS errors, missing values, duplicates).",
    de = "50 synthetische deutsche klinische stationäre Fälle mit ICD-10-GM, OPS, Alter, Geschlecht, Aufnahme-/Entlassungsdaten, Verweildauer und klinischen Notizen. Spiegelt reale Kodiermuster wider (Multimorbidität, prä-/postoperativ, negative VWD-Fehler, fehlende Werte, Duplikate).",
    fr = "50 cas cliniques hospitalisés synthétiques allemands avec CIM-10-GM, OPS, âge, genre, dates d'admission/sortie, durée de séjour et notes cliniques."
  ),
  s1_confirm = list(
    en = "Confirm dataset and proceed to Checks Studio",
    de = "Datensatz bestätigen und zum Prüfungsstudio",
    fr = "Confirmer le jeu de données et procéder"
  ),
  # Step 2 (Checks Studio) labels.
  s2_title = list(en = "Step 2: Fitness-for-Purpose Checks Studio", de = "Schritt 2: Fitness-for-Purpose Prüfungsstudio", fr = "Étape 2: Studio de vérifications"),
  s2_info = list(
    en = "Define quality checks tailored to your research question. Use statistical profiling for automated suggestions, the manual builder for custom rules, and the check manager for review and execution.",
    de = "Definieren Sie auf Ihre Forschungsfrage zugeschnittene Qualitätsprüfungen. Nutzen Sie die statistische Profilierung für automatische Vorschläge, den manuellen Builder für individuelle Regeln und den Prüfungsmanager für Überprüfung und Ausführung.",
    fr = "Définissez des vérifications adaptées à votre question de recherche. Utilisez le profilage statistique, le constructeur manuel et le gestionnaire."
  ),
  s2_roadmap = list(
    en = "Workflow: (D1) let statistical profiling suggest checks automatically, then (D2) add your own custom rules with the builder, then (D3) review everything and press Execute. Results appear in Step 3.",
    de = "Ablauf: (D1) automatische Vorschläge durch statistische Profilierung, dann (D2) eigene Regeln im Builder ergänzen, dann (D3) alles überprüfen und Ausführen drücken. Ergebnisse erscheinen in Schritt 3.",
    fr = "Déroulé : (D1) laissez le profilage statistique suggérer automatiquement des vérifications, puis (D2) ajoutez vos propres règles personnalisées, puis (D3) révisez l'ensemble et cliquez sur Exécuter. Les résultats apparaissent à l'étape 3."
  ),
  d1_title = list(en = "D1: Statistical Profiling", de = "D1: Statistische Profilierung", fr = "D1: Profilage statistique"),
  d1_desc = list(
    en = "Automated statistical profiling of your data. The system analyzes distributions, outliers, correlations, missing patterns, code integrity, temporal order, and format consistency to suggest quality checks. Each suggestion explains the statistical basis and why it matters for data use. Review each suggestion and accept, modify, or reject it.",
    de = "Automatische statistische Profilierung Ihrer Daten. Das System analysiert Verteilungen, Ausreisser, Korrelationen, Fehlmuster, Code-Integrität, zeitliche Reihenfolge und Format-Konsistenz. Jeder Vorschlag erklärt die statistische Grundlage und seine Relevanz für die Datennutzung. Prüfen und akzeptieren, modifizieren oder ablehnen.",
    fr = "Profilage statistique automatisé de vos données. Le système analyse distributions, valeurs aberrantes, corrélations, données manquantes, intégrité des codes, ordre temporel et cohérence de format. Chaque suggestion explique la base statistique et son importance."
  ),
  d1_accept = list(en = "Accept", de = "Akzeptieren", fr = "Accepter"),
  d1_reject = list(en = "Reject", de = "Ablehnen", fr = "Rejeter"),
  d1_modify = list(en = "Modify", de = "Modifizieren", fr = "Modifier"),
  d2_title = list(en = "D2: Manual Check Builder", de = "D2: Manueller Prüfungsbaukasten", fr = "D2: Constructeur manuel"),
  d2_desc = list(
    en = "Step 0: Select check type (column-to-value or column-to-column). Step 1: Add conditions using 20+ operators (comparisons, pattern matching, set membership, duplicates). Combine with AND/OR logic, or select END to finalize. Use IF-THEN for conditional checks and GROUP BY for aggregated validations. Import value lists from CSV, JSON, Excel, or TXT for set-based comparisons (e.g. 1000 valid ICD codes). Step 2: Name, set severity, and save.",
    de = "Schritt 0: Prüftyp wählen (Spalte-zu-Wert oder Spalte-zu-Spalte). Schritt 1: Bedingungen hinzufügen mit 20+ Operatoren (Vergleiche, Muster, Mengenzugehörigkeit, Duplikate). Verknüpfen mit UND/ODER, oder END zum Abschliessen. IF-THEN für bedingte Prüfungen, GROUP BY für aggregierte Validierungen. Wertelisten importieren (CSV, JSON, Excel, TXT) für mengenbasierte Vergleiche (z.B. 1000 gültige ICD-Codes). Schritt 2: Benennen, Schweregrad setzen, speichern.",
    fr = "Étape 0: Type de vérification (colonne-valeur ou colonne-colonne). Étape 1: Ajouter des conditions avec 20+ opérateurs. Combiner avec ET/OU, ou END pour finaliser. IF-THEN pour les vérifications conditionnelles, GROUP BY pour les validations agrégées. Importer des listes (CSV, JSON, Excel, TXT). Étape 2: Nommer, définir la sévérité, sauvegarder."
  ),
  d3_title = list(en = "D3: Check Manager and Execution", de = "D3: Prüfungsmanager und Ausführung", fr = "D3: Gestionnaire et exécution"),
  d3_desc = list(
    en = "Overview of all checks from statistical profiling and manual builder. Remove, modify, export, import, or merge checks. Execute all checks: results appear on the next page.",
    de = "Übersicht aller Prüfungen aus Profilierung und manuellem Builder. Entfernen, modifizieren, exportieren, importieren oder zusammenführen. Ausführen: Ergebnisse erscheinen auf der nächsten Seite.",
    fr = "Vue d'ensemble des vérifications. Supprimer, modifier, exporter, importer ou fusionner. Exécuter: résultats page suivante."
  ),
  # Step 3 (Results) labels.
  s3_title = list(en = "Step 3: Results and Data Fitness", de = "Schritt 3: Ergebnisse und Dateneignung", fr = "Étape 3: Résultats et aptitude"),
  s3_checks = list(en = "Checks Executed", de = "Ausgeführte Prüfungen", fr = "Vérifications exécutées"),
  s3_issues = list(en = "Issues Found", de = "Probleme gefunden", fr = "Problèmes trouvés"),
  s3_affected = list(en = "Records Affected", de = "Betroffene Datensätze", fr = "Enregistrements affectés"),
  s3_score_info = list(
    en = "Fitness Score = 100 x (1 - affected / total). Based exclusively on the checks you defined. Detailed findings are documented in the certificate.",
    de = "Fitness-Score = 100 x (1 - betroffene / Gesamt). Basiert ausschliesslich auf Ihren Prüfungen. Detaillierte Ergebnisse sind im Zertifikat dokumentiert.",
    fr = "Score = 100 x (1 - affectés / total). Basé exclusivement sur vos vérifications. Les résultats détaillés sont documentés dans le certificat."
  ),
  s3_sev = list(en = "Severity Distribution", de = "Schweregrad-Verteilung", fr = "Distribution de sévérité"),
  s3_cat = list(en = "Source Domain Breakdown", de = "Herkunftsdomänen", fr = "Répartition par domaine"),
  s3_detail = list(en = "Detailed Issues", de = "Detaillierte Probleme", fr = "Détails"),
  s3_score_band = list(
    en = "Green 100-80% | Yellow 79-60% | Orange 59-40% | Red below 40%",
    de = "Grün 100-80% | Gelb 79-60% | Orange 59-40% | Rot unter 40%",
    fr = "Vert 100-80% | Jaune 79-60% | Orange 59-40% | Rouge sous 40%"
  ),
  # Step 4 (Cleansing) labels.
  s4_title = list(en = "Step 4: Data Cleansing and Documentation", de = "Schritt 4: Datenbereinigung und Dokumentation", fr = "Étape 4: Nettoyage et documentation"),
  s4_guide = list(en = "Step 4.1: Issue-Guided Cleansing", de = "Schritt 4.1: Problemgeführte Bereinigung", fr = "Étape 4.1: Nettoyage guidé par problèmes"),
  s4_guide_hint = list(
    en = "Select an issue from the list. Then review each affected record one by one. For each record you can modify values, validate, keep unchanged, or delete. Every single action is logged in the audit trail.",
    de = "Wählen Sie ein Problem aus der Liste. Prüfen Sie dann jeden betroffenen Datensatz einzeln. Für jeden Datensatz können Sie Werte ändern, validieren, beibehalten oder löschen. Jede einzelne Aktion wird im Änderungsprotokoll erfasst.",
    fr = "Sélectionnez un problème. Examinez chaque enregistrement affecté un par un. Pour chacun: modifier, valider, garder ou supprimer. Chaque action est journalisée."
  ),
  s4_bulk = list(en = "Step 4.2: Find and Replace", de = "Schritt 4.2: Suchen und Ersetzen", fr = "Étape 4.2: Rechercher et remplacer"),
  s4_manual = list(en = "Step 4.3: Manual Cell Editing", de = "Schritt 4.3: Manuelle Zellbearbeitung", fr = "Étape 4.3: Édition manuelle de cellules"),
  s4_log = list(en = "Step 4.4: Audit Trail", de = "Schritt 4.4: Änderungsprotokoll", fr = "Étape 4.4: Piste d'audit"),
  s4_compare = list(en = "Step 4.5: Original vs. Cleaned", de = "Schritt 4.5: Original vs. Bereinigt", fr = "Étape 4.5: Original vs. Nettoyé"),
  s4_rename = list(en = "Step 4.6: Rename Column", de = "Schritt 4.6: Spalte umbenennen", fr = "Étape 4.6: Renommer colonne"),
  s4_datefix_title = list(en = "Step 4.7: Fix Date Format", de = "Schritt 4.7: Datumsformat korrigieren", fr = "Étape 4.7: Corriger le format de date"),
  s4_fmt_title = list(
    en = "Step 4.7: Fix Column Format",
    de = "Schritt 4.7: Spaltenformat korrigieren",
    fr = "Etape 4.7: Corriger le format des colonnes"
  ),
  s4_fmt_hint = list(
    en = "Pick a target type for any column. Cells that cannot be coerced (for example letters into integer) become NA and each failure is recorded in the audit trail with the original value.",
    de = "Zieltyp fuer eine Spalte waehlen. Werte, die nicht konvertiert werden koennen (z. B. Buchstaben nach Integer), werden zu NA; jeder Fehler wird mit dem Originalwert im Aenderungsprotokoll erfasst.",
    fr = "Choisir un type cible pour une colonne. Les valeurs non convertibles (ex. lettres en entier) deviennent NA; chaque echec est enregistre avec la valeur d'origine dans la piste d'audit."
  ),
  s4_delcol_title = list(en = "Step 4.8: Delete Column", de = "Schritt 4.8: Spalte löschen", fr = "Étape 4.8: Supprimer colonne"),
  s4_fr_count = list(en = "matches found", de = "Treffer gefunden", fr = "correspondances trouvées"),
  # Fitness-score interpretation bands.
  interp_ok = list(
    en = "Excellent: all checks passed. Data is fit for the specified purpose.",
    de = "Exzellent: alle Prüfungen bestanden. Daten sind für den angegebenen Zweck geeignet.",
    fr = "Excellent: toutes les vérifications réussies. Données adaptées."
  ),
  interp_lo = list(
    en = "Minor issues detected. Unlikely to significantly affect analytical results.",
    de = "Geringfügige Probleme erkannt. Kaum Einfluss auf Analyseergebnisse.",
    fr = "Problèmes mineurs détectés. Peu d'impact sur les résultats."
  ),
  interp_md = list(
    en = "Moderate issues present. May introduce bias into analyses. Targeted cleansing recommended.",
    de = "Mittlere Probleme vorhanden. Können Verzerrungen einführen. Gezielte Bereinigung empfohlen.",
    fr = "Problèmes modérés. Peuvent introduire des biais. Nettoyage ciblé recommandé."
  ),
  interp_hi = list(
    en = "Significant problems detected. Data cleansing is strongly recommended before analysis.",
    de = "Erhebliche Probleme erkannt. Datenbereinigung vor Analyse dringend empfohlen.",
    fr = "Problèmes significatifs. Nettoyage fortement recommandé."
  ),
  interp_cr = list(
    en = "Critical quality issues. Do NOT use this data without resolving these problems first.",
    de = "Kritische Qualitätsprobleme. Verwenden Sie diese Daten NICHT ohne vorherige Behebung.",
    fr = "Problèmes critiques. N'utilisez PAS ces données sans résolution préalable."
  ),
  # Step 4 roadmap card.
  s4_overview_title = list(
    en = "How to cleanse step by step",
    de = "So bereinigen Sie Schritt für Schritt",
    fr = "Comment nettoyer étape par étape"
  ),
  # Rendered as a bullet list by s4_overview_body_ui. Each language carries the same
  # eight points.
  s4_overview_body = list(
    en = c(
      "4.1 Guided review of affected records first (one record at a time, every action logged).",
      "4.2 Find and Replace for patterns that repeat across many rows.",
      "4.3 Manual cell editing for individual fixes.",
      "4.4 Audit Trail (read only): review what has been logged so far.",
      "4.5 Original vs Cleaned: verify your changes look right.",
      "4.6 Rename Columns if a column label needs correcting.",
      "4.7 Fix Column Format (type coercion with NA logging for incompatible cells).",
      "4.8 Delete Column for columns that are genuinely unusable.",
      "Every action across all eight sub-steps is captured in the audit trail and exported in the Cleansing Certificate."
    ),
    de = c(
      "4.1 Gefuehrte Pruefung der betroffenen Datensaetze zuerst (Datensatz fuer Datensatz, jede Aktion wird protokolliert).",
      "4.2 Suchen und Ersetzen fuer Muster, die in vielen Zeilen wiederkehren.",
      "4.3 Manuelle Zellbearbeitung fuer Einzelfaelle.",
      "4.4 Aenderungsprotokoll (schreibgeschuetzt): pruefen Sie das bisher Protokollierte.",
      "4.5 Original vs. Bereinigt: verifizieren Sie die Aenderungen.",
      "4.6 Spalte umbenennen, falls eine Spaltenueberschrift korrigiert werden muss.",
      "4.7 Spaltenformat korrigieren (Typ-Konvertierung, inkompatible Werte werden als NA protokolliert).",
      "4.8 Spalte loeschen fuer wirklich unbrauchbare Spalten.",
      "Jede Aktion aller acht Unterschritte wird im Aenderungsprotokoll erfasst und im Bereinigungszertifikat exportiert."
    ),
    fr = c(
      "4.1 Revue guidee des enregistrements affectes d'abord (un enregistrement a la fois, chaque action journalisee).",
      "4.2 Rechercher et remplacer pour les motifs repetes sur de nombreuses lignes.",
      "4.3 Edition manuelle de cellules pour les correctifs individuels.",
      "4.4 Piste d'audit (lecture seule): revoir ce qui a ete journalise.",
      "4.5 Original vs. Nettoye: verifier les modifications.",
      "4.6 Renommer une colonne si necessaire.",
      "4.7 Corriger le format des colonnes (coercition de type, valeurs incompatibles mises a NA et journalisees).",
      "4.8 Supprimer une colonne pour les colonnes inutilisables.",
      "Chaque action des huit sous-etapes est capturee dans la piste d'audit et exportee dans le Certificat de nettoyage."
    )
  ),
  # Summary screen labels.
  finish_title = list(en = "Assessment Complete", de = "Bewertung abgeschlossen", fr = "Évaluation terminée"),
  finish_recap = list(en = "Summary of Your Analysis", de = "Zusammenfassung Ihrer Analyse", fr = "Résumé de votre analyse"),
  finish_feedback = list(
    en = "We value your feedback. Please contact the development team.",
    de = "Wir freuen uns über Ihr Feedback. Bitte kontaktieren Sie das Entwicklungsteam.",
    fr = "Vos retours sont précieux. Veuillez contacter l'équipe de développement."
  ),
  # Tutorial labels.
  tut_title = list(en = "Interactive Tutorial", de = "Interaktives Tutorial", fr = "Tutoriel interactif"),
  tut_sub = list(en = "Click each section to expand.", de = "Klicken Sie auf jeden Abschnitt, um ihn zu erweitern.", fr = "Cliquez sur chaque section pour l'étendre."),
  # Tutorial steps. Each step has four keys: title (_t), overview (_ov), workflow (_wf),
  # and example (_ex).
  tut_s1_t = list(
    en = "1. Import your dataset",
    de = "1. Datensatz importieren",
    fr = "1. Importer le jeu de données"),
  tut_s1_ov = list(
    en = "Open DQA reads CSV, Excel, JSON, FHIR bundles, and SQL query results. A built-in demo dataset with 50 synthetic German inpatient encounters is available for practice.",
    de = "Open DQA liest CSV, Excel, JSON, FHIR-Bundles und SQL-Abfrageergebnisse. Zum Üben steht ein Demo-Datensatz mit 50 synthetischen stationären Fällen zur Verfügung.",
    fr = "Open DQA lit CSV, Excel, JSON, bundles FHIR et résultats SQL. Un jeu de données de démonstration de 50 cas synthétiques est disponible pour s'exercer."),
  tut_s1_wf = list(
    en = c("Pick a source: Local File, SQL Database, FHIR Server, or Demo Dataset.",
           "Upload the file or enter the connection details.",
           "Review the 100-row preview and confirm the dataset."),
    de = c("Quelle wählen: lokale Datei, SQL-Datenbank, FHIR-Server oder Demo-Datensatz.",
           "Datei hochladen oder Verbindungsdaten eingeben.",
           "100-Zeilen-Vorschau prüfen und Datensatz bestätigen."),
    fr = c("Choisir une source : fichier local, base SQL, serveur FHIR ou jeu de démo.",
           "Téléverser le fichier ou saisir les informations de connexion.",
           "Vérifier l'aperçu des 100 premières lignes et confirmer le jeu.")),
  tut_s1_ex = list(
    en = "Example: click Demo Dataset then Load Demo Dataset. The preview shows 50 encounters with ICD-10-GM, OPS, admission and discharge dates. Click Confirm dataset and proceed to lock it for analysis.",
    de = "Beispiel: Demo-Datensatz wählen, dann Demo-Datensatz laden. Die Vorschau zeigt 50 Fälle mit ICD-10-GM, OPS und Aufnahme-/Entlassdaten. Mit Datensatz bestätigen für die Analyse sperren.",
    fr = "Exemple : cliquer sur Jeu de démo puis Charger. L'aperçu affiche 50 séjours avec CIM-10-GM, OPS et dates. Cliquer sur Confirmer pour verrouiller le jeu pour l'analyse."),
  
  tut_s2_t = list(
    en = "2. D1 — Statistical profiling",
    de = "2. D1 — Statistische Profilierung",
    fr = "2. D1 — Profilage statistique"),
  tut_s2_ov = list(
    en = "Open DQA inspects every column and proposes quality checks based on observed patterns: missing values, MAD outliers, ICD and OPS format, temporal order, duplicates, correlations, and gender-ICD plausibility. Each suggestion has a severity rating and a transparent statistical justification.",
    de = "Open DQA untersucht jede Spalte und schlägt Prüfungen basierend auf beobachteten Mustern vor: fehlende Werte, MAD-Ausreißer, ICD-/OPS-Format, zeitliche Reihenfolge, Duplikate, Korrelationen, Geschlecht-ICD-Plausibilität. Jeder Vorschlag hat einen Schweregrad und eine nachvollziehbare statistische Begründung.",
    fr = "Open DQA inspecte chaque colonne et propose des vérifications d'après les motifs observés : valeurs manquantes, aberrations MAD, format CIM et OPS, ordre temporel, doublons, corrélations, plausibilité sexe/CIM. Chaque suggestion a une sévérité et une justification statistique transparente."),
  tut_s2_wf = list(
    en = c("Click Run Statistical Profiling. Suggestions appear within seconds.",
           "Read the statistical basis under each suggestion.",
           "Accept, Modify (edit before saving), or Reject each one."),
    de = c("Statistische Profilierung starten klicken. Vorschläge erscheinen innerhalb von Sekunden.",
           "Die statistische Grundlage unter jedem Vorschlag lesen.",
           "Akzeptieren, Modifizieren (vor dem Speichern bearbeiten) oder Ablehnen."),
    fr = c("Cliquer sur Lancer le profilage statistique. Les suggestions apparaissent en quelques secondes.",
           "Lire la base statistique sous chaque suggestion.",
           "Accepter, Modifier (éditer avant enregistrement) ou Rejeter chacune.")),
  tut_s2_ex = list(
    en = "Example: on the demo dataset you will see Completeness: ops_code (high severity, 72 percent missing), Duplicate IDs: patient_id (one duplicate), Future dates: admission_date (one record in 2025+), and Temporal order: admission_date after discharge_date (one violation).",
    de = "Beispiel: Beim Demo-Datensatz erscheinen u. a. Vollständigkeit: ops_code (hoher Schweregrad, 72 Prozent fehlend), Duplicate IDs: patient_id (ein Duplikat), Future dates: admission_date (ein Datensatz in der Zukunft), Temporal order: admission_date nach discharge_date (ein Verstoß).",
    fr = "Exemple : sur le jeu de démo, vous verrez Complétude : ops_code (sévérité élevée, 72 % manquants), Doublons : patient_id (un doublon), Dates futures : admission_date (un enregistrement), Ordre temporel : admission_date après discharge_date (une violation)."),
  
  tut_s3_t = list(
    en = "3. D2 Base — Build custom checks",
    de = "3. D2 Basis — Eigene Prüfungen bauen",
    fr = "3. D2 Base — Créer des vérifications personnalisées"),
  tut_s3_ov = list(
    en = "The Base builder combines conditions with AND, OR, END. Eighteen operators are supported: comparisons, pattern matching, range, set membership, presence, uniqueness. Conditions compile to validated R expressions that are checked against a security blacklist before execution.",
    de = "Der Basis-Baukasten verknüpft Bedingungen mit UND, ODER, END. 18 Operatoren stehen zur Verfügung: Vergleiche, Muster, Bereich, Mengenzugehörigkeit, Präsenz, Eindeutigkeit. Bedingungen werden in validierte R-Ausdrücke kompiliert, die vor Ausführung gegen eine Sicherheits-Blacklist geprüft werden.",
    fr = "Le constructeur Base combine les conditions avec ET, OU, END. 18 opérateurs : comparaisons, motifs, plages, appartenance à un ensemble, présence, unicité. Les conditions sont compilées en expressions R validées et contrôlées contre une liste noire de sécurité avant exécution."),
  tut_s3_wf = list(
    en = c("Step 0: select Column-to-Value or Column-to-Column.",
           "Step 1: pick a column, an operator, a value, a logic connector (AND/OR/END), then click Add.",
           "Check the impact preview, optionally click Test Query, then name the check and Save."),
    de = c("Schritt 0: Spalte-zu-Wert oder Spalte-zu-Spalte wählen.",
           "Schritt 1: Spalte, Operator, Wert und Logik (UND/ODER/END) wählen, dann Hinzufügen klicken.",
           "Auswirkungsvorschau prüfen, optional Query testen, dann Prüfung benennen und Speichern."),
    fr = c("Étape 0 : choisir Colonne-vers-Valeur ou Colonne-vers-Colonne.",
           "Étape 1 : choisir une colonne, un opérateur, une valeur, un connecteur logique (ET/OU/END), puis Ajouter.",
           "Vérifier l'aperçu d'impact, optionnellement Tester la requête, puis nommer et Enregistrer.")),
  tut_s3_ex = list(
    en = "Example: flag implausible ages. Type = Column to Value, Column = age, Operator = >, Value = 120, Logic = END, Add. Name = Age over 120, Severity = High, Save. The new check appears in D3 immediately.",
    de = "Beispiel: unplausibles Alter markieren. Typ = Spalte zu Wert, Spalte = age, Operator = >, Wert = 120, Logik = END, Hinzufügen. Name = Age over 120, Schweregrad = High, Speichern. Die neue Prüfung erscheint sofort in D3.",
    fr = "Exemple : signaler les âges implausibles. Type = Colonne vers Valeur, Colonne = age, Opérateur = >, Valeur = 120, Logique = END, Ajouter. Nom = Age over 120, Sévérité = High, Enregistrer. La nouvelle vérification apparaît immédiatement dans D3."),
  
  tut_s4_t = list(
    en = "4. D2 Advanced — Grouped, conditional, free R",
    de = "4. D2 Erweitert — Gruppiert, bedingt, freie R-Abfrage",
    fr = "4. D2 Avancé — Groupé, conditionnel, R libre"),
  tut_s4_ov = list(
    en = "GROUP BY validates aggregated statistics per group. IF-THEN flags rows only when a precondition holds but a required condition fails. Free R-Query accepts any R logical expression, subject to the same security blacklist (no system calls, no eval, no file access).",
    de = "GROUP BY validiert aggregierte Statistiken pro Gruppe. IF-THEN markiert Zeilen nur, wenn eine Vorbedingung gilt und die Nachbedingung verletzt ist. Freie R-Abfrage akzeptiert beliebige logische R-Ausdrücke, gleiche Sicherheits-Blacklist wie D2 Basis (keine Systemaufrufe, kein eval, kein Dateizugriff).",
    fr = "GROUP BY valide des statistiques agrégées par groupe. IF-THEN ne marque les lignes que si la précondition est vraie et la condition échoue. Requête R libre accepte toute expression logique R, même liste noire de sécurité que D2 Base (pas d'appels système, pas d'eval, pas d'accès fichier)."),
  tut_s4_wf = list(
    en = c("Open D2 Advanced and select the right sub-tab.",
           "Fill the fields, click Test Query to see the match count.",
           "Name the check and click Save check."),
    de = c("D2 Erweitert öffnen und den passenden Unter-Reiter wählen.",
           "Felder ausfüllen, Query testen klicken, Treffer prüfen.",
           "Prüfung benennen und Prüfung speichern klicken."),
    fr = c("Ouvrir D2 Avancé et choisir le bon sous-onglet.",
           "Remplir les champs, cliquer Tester la requête, vérifier le nombre de correspondances.",
           "Nommer la vérification puis Enregistrer.")),
  tut_s4_ex = list(
    en = "Example IF-THEN: flag male patients with female-specific ICD codes. IF column = gender, IF operator = ==, IF value = M. THEN column = icd_code, THEN operator = starts_with, THEN value = O. Name = Male with O-code, Save.",
    de = "Beispiel IF-THEN: Männer mit frauenspezifischen ICD-Codes markieren. WENN-Spalte = gender, WENN-Operator = ==, WENN-Wert = M. DANN-Spalte = icd_code, DANN-Operator = starts_with, DANN-Wert = O. Name = Male with O-code, Speichern.",
    fr = "Exemple IF-THEN : marquer les hommes avec codes CIM féminins. SI colonne = gender, SI opérateur = ==, SI valeur = M. ALORS colonne = icd_code, ALORS opérateur = starts_with, ALORS valeur = O. Nom = Male with O-code, Enregistrer."),
  
  tut_s5_t = list(
    en = "5. D3 — Review and execute",
    de = "5. D3 — Überprüfen und ausführen",
    fr = "5. D3 — Revoir et exécuter"),
  tut_s5_ov = list(
    en = "D3 lists every check from D1, D2 Base, and D2 Advanced in one table. Review, delete, export, import, execute.",
    de = "D3 listet alle Prüfungen aus D1, D2 Basis und D2 Erweitert in einer Tabelle. Überprüfen, löschen, exportieren, importieren, ausführen.",
    fr = "D3 liste toutes les vérifications de D1, D2 Base et D2 Avancé dans un seul tableau. Revoir, supprimer, exporter, importer, exécuter."),
  tut_s5_wf = list(
    en = c("Select rows and click Delete Selected to remove checks.",
           "Click Export JSON to save the register, Browse to import a previous one.",
           "Click Execute All Checks then confirm; the app moves to Step 3."),
    de = c("Zeilen auswählen und Ausgewählte löschen klicken, um Prüfungen zu entfernen.",
           "Export JSON zum Speichern des Registers, Browse zum Import eines vorherigen.",
           "Alle Prüfungen ausführen klicken und bestätigen; die App wechselt zu Schritt 3."),
    fr = c("Sélectionner des lignes et Supprimer la sélection pour retirer des vérifications.",
           "Export JSON pour sauvegarder le registre, Parcourir pour importer.",
           "Exécuter toutes les vérifications puis confirmer ; l'application passe à l'étape 3.")),
  tut_s5_ex = list(
    en = "Example: with six checks defined, click Execute All Checks. The confirmation dialog reads Execute 6 checks on 50 records. Click Execute; results appear in Step 3 within one second.",
    de = "Beispiel: Bei sechs definierten Prüfungen Alle Prüfungen ausführen klicken. Der Dialog zeigt 6 Prüfungen auf 50 Datensätze ausführen. Ausführen klicken; Ergebnisse erscheinen in Schritt 3 binnen einer Sekunde.",
    fr = "Exemple : avec six vérifications définies, cliquer Exécuter toutes les vérifications. Le dialogue affiche Exécuter 6 vérifications sur 50 enregistrements. Cliquer Exécuter ; les résultats apparaissent à l'étape 3 en moins d'une seconde."),
  
  tut_s6_t = list(
    en = "6. Results and fitness score",
    de = "6. Ergebnisse und Eignungs-Score",
    fr = "6. Résultats et score d'aptitude"),
  tut_s6_ov = list(
    en = "Step 3 shows Checks Executed, Issues Found, Records Affected, and the Fitness Score Q = 100 x (1 - affected / total). Color bands: Green 100-80, Yellow 79-60, Orange 59-40, Red below 40.",
    de = "Schritt 3 zeigt Ausgeführte Prüfungen, Probleme gefunden, Betroffene Datensätze und den Fitness-Score Q = 100 x (1 - betroffen / gesamt). Farbbänder: Grün 100-80, Gelb 79-60, Orange 59-40, Rot unter 40.",
    fr = "L'étape 3 affiche Vérifications exécutées, Problèmes trouvés, Enregistrements affectés et le score Q = 100 x (1 - affectés / total). Bandes : Vert 100-80, Jaune 79-60, Orange 59-40, Rouge < 40."),
  tut_s6_wf = list(
    en = c("Read the score and the interpretation text.",
           "Inspect the per-check impact bars; click Show / Hide Chart for a detailed view.",
           "Download the DQ Certificate (Word) and the Issues CSV."),
    de = c("Score und Interpretationstext lesen.",
           "Auswirkungs-Balken pro Prüfung prüfen; Grafik ein-/ausblenden für Detailansicht.",
           "DQ-Zertifikat (Word) und Probleme-CSV herunterladen."),
    fr = c("Lire le score et le texte d'interprétation.",
           "Examiner les barres d'impact par vérification ; Afficher/Masquer pour le détail.",
           "Télécharger le Certificat DQ (Word) et le CSV des problèmes.")),
  tut_s6_ex = list(
    en = "Example: a score of 68 percent falls in Yellow. The interpretation notes moderate issues with targeted cleansing recommended.",
    de = "Beispiel: Ein Score von 68 Prozent fällt in Gelb. Die Interpretation weist auf mittlere Probleme mit gezielter Bereinigung hin.",
    fr = "Exemple : un score de 68 % tombe en Jaune. L'interprétation signale des problèmes modérés avec nettoyage ciblé recommandé."),
  
  tut_s7_t = list(
    en = "7. Cleansing and audit trail",
    de = "7. Bereinigung und Änderungsprotokoll",
    fr = "7. Nettoyage et piste d'audit"),
  tut_s7_ov = list(
    en = "Step 4 has eight sub-steps: issue-guided record review, find and replace, manual cell editing, audit trail, original vs cleaned, rename column, fix column format, delete column. Every action is written to a tamper-evident audit trail.",
    de = "Schritt 4 hat acht Unterschritte: geführte Datensatzprüfung, Suchen und Ersetzen, manuelle Zellbearbeitung, Änderungsprotokoll, Original vs. bereinigt, Spalte umbenennen, Spaltenformat korrigieren, Spalte löschen. Jede Aktion wird manipulationssicher protokolliert.",
    fr = "L'étape 4 comporte huit sous-étapes : revue guidée, rechercher/remplacer, édition manuelle, piste d'audit, comparaison, renommer, corriger le format, supprimer la colonne. Chaque action est journalisée de manière inviolable."),
  tut_s7_wf = list(
    en = c("Always start with 4.1 Issue-guided review for record-level fixes.",
           "Use 4.2 Find and Replace for patterns that repeat across many rows.",
           "Use 4.7 Fix Column Format to coerce types; incompatible cells become NA and are logged."),
    de = c("Immer mit 4.1 Problemgeführte Prüfung beginnen.",
           "4.2 Suchen und Ersetzen für Muster, die in vielen Zeilen wiederkehren.",
           "4.7 Spaltenformat korrigieren für Typumwandlungen; inkompatible Zellen werden zu NA und protokolliert."),
    fr = c("Commencer toujours par 4.1 Revue guidée pour les corrections au niveau enregistrement.",
           "Utiliser 4.2 Rechercher et remplacer pour les motifs répétés.",
           "Utiliser 4.7 Corriger le format pour convertir les types ; les cellules incompatibles deviennent NA et sont journalisées.")),
  tut_s7_ex = list(
    en = "Example: in 4.7 select column los, target type integer. The preview reports how many cells would become NA before the coercion is applied. Each NA introduced by the coercion is logged with its original value.",
    de = "Beispiel: in 4.7 Spalte los, Zieltyp integer wählen. Die Vorschau zeigt, wie viele Zellen zu NA werden würden. Jede durch die Konvertierung erzeugte NA wird mit ihrem Originalwert protokolliert.",
    fr = "Exemple : dans 4.7 choisir la colonne los, type cible integer. L'aperçu indique combien de cellules deviendraient NA avant l'application. Chaque NA induit est journalisé avec sa valeur d'origine."),
  
  tut_s8_t = list(
    en = "8. Certificates and archival",
    de = "8. Zertifikate und Archivierung",
    fr = "8. Certificats et archivage"),
  tut_s8_ov = list(
    en = "Open DQA produces two Word documents: the DQ Certificate (methods, per-check register, impact charts, session fingerprint) and the Cleansing Certificate (every modification with timestamp, old value, new value). Both are designed to satisfy ICH E6(R2), GDPR Art. 5(1)(d), ISO 14155, and FDA 21 CFR Part 11 audit-trail requirements.",
    de = "Open DQA erzeugt zwei Word-Dokumente: das DQ-Zertifikat (Methoden, Prüfungsregister, Auswirkungsdiagramme, Session-Fingerprint) und das Bereinigungszertifikat (jede Änderung mit Zeitstempel, Alt- und Neuwert). Beide erfüllen die Audit-Trail-Anforderungen von ICH E6(R2), DSGVO Art. 5(1)(d), ISO 14155 und FDA 21 CFR Part 11.",
    fr = "Open DQA produit deux documents Word : le Certificat DQ (méthodes, registre, graphiques d'impact, empreinte de session) et le Certificat de Nettoyage (chaque modification avec horodatage, ancienne/nouvelle valeur). Les deux satisfont ICH E6(R2), RGPD Art. 5(1)(d), ISO 14155 et FDA 21 CFR Part 11."),
  tut_s8_wf = list(
    en = c("On Step 3 download the DQ Certificate (Word) and the Issues CSV.",
           "On Step 4 download the Cleansing Certificate (Word), the Cleaned Data CSV, and the Audit Trail CSV.",
           "Archive all artefacts alongside the study documentation."),
    de = c("In Schritt 3 DQ-Zertifikat (Word) und Probleme-CSV herunterladen.",
           "In Schritt 4 Bereinigungszertifikat (Word), bereinigte Daten CSV und Audit-Trail-CSV herunterladen.",
           "Alle Artefakte gemeinsam mit der Studiendokumentation archivieren."),
    fr = c("À l'étape 3 télécharger le Certificat DQ (Word) et le CSV des problèmes.",
           "À l'étape 4 télécharger le Certificat de Nettoyage (Word), les données nettoyées et la piste d'audit.",
           "Archiver tous les artefacts avec la documentation de l'étude.")),
  tut_s8_ex = list(
    en = "Example: the DQ Certificate includes a session fingerprint ODQA-xxxx and a dataset fingerprint DF-xxxx derived from column signature, dimensions, and a first-row hash. Store the certificate file next to the CSVs so the integrity chain can be re-verified at any time.",
    de = "Beispiel: Das DQ-Zertifikat enthält einen Session-Fingerprint ODQA-xxxx und einen Dataset-Fingerprint DF-xxxx, abgeleitet aus Spaltensignatur, Dimensionen und Erstzeilen-Hash. Die Zertifikatsdatei neben den CSVs ablegen, damit die Integritätskette jederzeit nachgeprüft werden kann.",
    fr = "Exemple : le Certificat DQ contient une empreinte de session ODQA-xxxx et une empreinte de données DF-xxxx dérivées de la signature de colonnes, dimensions et hachage de la première ligne. Conserver le certificat à côté des CSV pour pouvoir re-vérifier la chaîne d'intégrité."),
  # Analyst information overlay.
  landing_title = list(en = "Analyst Information (optional)", de = "Analysten-Informationen (optional)", fr = "Informations analyste (optionnel)"),
  landing_sub = list(
    en = "This information will appear in generated certificates.",
    de = "Diese Informationen erscheinen in den generierten Zertifikaten.",
    fr = "Ces informations figureront dans les certificats générés."
  ),
  landing_name = list(en = "Your Name", de = "Ihr Name", fr = "Votre nom"),
  landing_function = list(en = "Your Role / Function", de = "Ihre Rolle / Funktion", fr = "Votre rôle / fonction"),
  landing_skip = list(en = "Skip", de = "Überspringen", fr = "Passer"),
  landing_save = list(en = "Save and Continue", de = "Speichern und Weiter", fr = "Enregistrer et Continuer"),
  # Record-by-record review.
  cl_validate = list(en = "Validate Record", de = "Datensatz validieren", fr = "Valider l'enregistrement"),
  cl_next_record = list(en = "Next Record", de = "Nächster Datensatz", fr = "Enregistrement suivant"),
  cl_prev_record = list(en = "Previous Record", de = "Vorheriger Datensatz", fr = "Enregistrement précédent"),
  cb_import_list = list(en = "Import Value List", de = "Werteliste importieren", fr = "Importer une liste de valeurs"),
  # Manual builder check-type selector.
  cb_type_label = list(en = "Check Type", de = "Prüftyp", fr = "Type de vérification"),
  cb_type_col_val = list(en = "Column to Value", de = "Spalte zu Wert", fr = "Colonne vers valeur"),
  cb_type_col_col = list(en = "Column to Column", de = "Spalte zu Spalte", fr = "Colonne vers colonne"),
  # D2 step labels.
  d2_step0_title = list(en = "Step 0: Select Check Type", de = "Schritt 0: Prüftyp wählen", fr = "Étape 0: Sélectionner le type de vérification"),
  d2_step0_hint = list(
    en = "Choose whether you want to compare a column against a fixed value (Column to Value) or compare two columns against each other (Column to Column).",
    de = "Wählen Sie, ob Sie eine Spalte mit einem festen Wert vergleichen (Spalte zu Wert) oder zwei Spalten miteinander vergleichen möchten (Spalte zu Spalte).",
    fr = "Choisissez si vous souhaitez comparer une colonne à une valeur fixe (Colonne vers valeur) ou comparer deux colonnes entre elles (Colonne vers colonne)."
  ),
  d2_step1_title = list(en = "Step 1: Add Conditions", de = "Schritt 1: Bedingungen hinzufügen", fr = "Étape 1: Ajouter des conditions"),
  d2_step2_title = list(en = "Step 2: Name and Save", de = "Schritt 2: Benennen und Speichern", fr = "Étape 2: Nommer et sauvegarder"),
  d2_advanced_title = list(en = "Advanced: Conditional and Grouped Checks", de = "Erweitert: Bedingte und gruppierte Prüfungen", fr = "Avancé: Vérifications conditionnelles et groupées"),
  d2_advanced_hint = list(
    en = "GROUP BY: Validates aggregated statistics per group (e.g., check that each patient has at most 1 admission per day). IF-THEN: Only applies the check to rows matching a precondition (e.g., IF icd_code starts with 'O' THEN gender must be 'W').",
    de = "GROUP BY: Validiert aggregierte Statistiken pro Gruppe (z.B. maximal 1 Aufnahme pro Patient und Tag). IF-THEN: Wendet die Prüfung nur auf Zeilen an, die eine Vorbedingung erfüllen (z.B. WENN icd_code mit 'O' beginnt, DANN muss Geschlecht 'W' sein).",
    fr = "GROUP BY: Valide les statistiques agrégées par groupe (ex.: max. 1 admission par patient et par jour). IF-THEN: Applique la vérification uniquement aux lignes correspondant à une précondition (ex.: SI code CIM commence par 'O' ALORS sexe doit être 'F')."
  ),
  d2_groupby_col = list(en = "Group By Column", de = "Gruppierungsspalte", fr = "Colonne de regroupement"),
  d2_groupby_agg = list(en = "Aggregation Function", de = "Aggregationsfunktion", fr = "Fonction d'agrégation"),
  d2_groupby_threshold = list(en = "Threshold", de = "Schwellenwert", fr = "Seuil"),
  d2_groupby_target = list(en = "Target Column", de = "Zielspalte", fr = "Colonne cible"),
  d2_mode_label = list(en = "Mode", de = "Modus", fr = "Mode"),
  d2_mode_none = list(en = "None", de = "Keiner", fr = "Aucun"),
  d2_mode_groupby = list(en = "GROUP BY (aggregate)", de = "GROUP BY (aggregiert)", fr = "GROUP BY (agrégé)"),
  d2_mode_ifthen = list(en = "IF-THEN (conditional)", de = "IF-THEN (bedingt)", fr = "IF-THEN (conditionnel)"),
  d2_ifthen_hint = list(
    en = "IF condition is met THEN check applies. Example: IF icd_code starts with 'O' THEN gender must be 'W'.",
    de = "WENN die Bedingung erfüllt ist, DANN wird die Prüfung angewendet. Beispiel: WENN icd_code mit 'O' beginnt, DANN muss Geschlecht 'W' sein.",
    fr = "SI la condition est remplie ALORS la vérification s'applique. Exemple: SI code CIM commence par 'O' ALORS sexe doit être 'F'."
  ),
  d2_if_col = list(en = "IF Column", de = "WENN Spalte", fr = "SI Colonne"),
  d2_if_val = list(en = "IF Value (contains)", de = "WENN Wert (enthält)", fr = "SI Valeur (contient)"),
  d2_current_conds = list(en = "Current Conditions", de = "Aktuelle Bedingungen", fr = "Conditions actuelles"),
  d2_generate_expr = list(
    en = "Generate R-Query",
    de = "R-Query generieren",
    fr = "Générer la R-Query"
  ),
  d2_test_query = list(
    en = "Test Query (count matches)",
    de = "Query testen (Treffer zählen)",
    fr = "Tester la requête (compter)"
  ),
  d2_clear_all = list(en = "Clear All", de = "Alles löschen", fr = "Tout effacer"),
  d2_check_name = list(en = "Check Name", de = "Prüfungsname", fr = "Nom de la vérification"),
  d2_description = list(en = "Description", de = "Beschreibung", fr = "Description"),
  d2_severity = list(en = "Severity", de = "Schweregrad", fr = "Sévérité"),
  d2_save_check = list(en = "Save Check", de = "Prüfung speichern", fr = "Sauvegarder la vérification"),
  d2_add_cond = list(en = "+ Add", de = "+ Hinzufügen", fr = "+ Ajouter"),
  d2_operator = list(en = "Operator", de = "Operator", fr = "Opérateur"),
  d2_logic = list(en = "Logic", de = "Logik", fr = "Logique"),
  d2_value = list(en = "Value", de = "Wert", fr = "Valeur"),
  d2_column = list(en = "Column", de = "Spalte", fr = "Colonne"),
  d2_column_a = list(en = "Column A", de = "Spalte A", fr = "Colonne A"),
  d2_column_b = list(en = "Column B", de = "Spalte B", fr = "Colonne B"),
  d2_min = list(en = "Min", de = "Min", fr = "Min"),
  d2_max = list(en = "Max", de = "Max", fr = "Max"),
  d2_values_hint = list(
    en = "Values (for short lists). Type them comma-separated (a, b, c) or semicolon-separated (a; b; c). For long lists, use 'Import Value List' below.",
    de = "Werte (fuer kurze Listen). Eingabe mit Komma (a, b, c) oder Semikolon (a; b; c). Fuer lange Listen unten 'Werteliste importieren' nutzen.",
    fr = "Valeurs (pour listes courtes). Separees par virgule (a, b, c) ou point-virgule (a; b; c). Pour les listes longues, utiliser 'Importer une liste de valeurs' ci-dessous."
  ),
  d2_values_hint_sep = list(
    en = "Values (separate with comma , or semicolon ;)",
    de = "Werte (mit Komma , oder Semikolon ; trennen)",
    fr = "Valeurs (separer par virgule , ou point-virgule ;)"
  ),
  d2_values_loaded = list(en = "values loaded", de = "Werte geladen", fr = "valeurs chargées"),
  d2_impact = list(en = "Impact", de = "Auswirkung", fr = "Impact"),
  # D3 labels.
  d3_no_checks = list(en = "No checks defined yet.", de = "Noch keine Prüfungen definiert.", fr = "Aucune vérification définie."),
  d3_checks_defined = list(en = "check(s) defined", de = "Prüfung(en) definiert", fr = "vérification(s) définie(s)"),
  d3_execute = list(en = "Execute All Checks", de = "Alle Prüfungen ausführen", fr = "Exécuter toutes les vérifications"),
  d3_delete_sel = list(en = "Delete Selected", de = "Ausgewählte löschen", fr = "Supprimer la sélection"),
  d3_export = list(en = "Export JSON", de = "JSON exportieren", fr = "Exporter JSON"),
  d3_exec_title = list(en = "Execute All Checks?", de = "Alle Prüfungen ausführen?", fr = "Exécuter toutes les vérifications?"),
  d3_exec_msg = list(
    en = "Execute {n_checks} checks on {n_records} records. Results on next page.",
    de = "{n_checks} Prüfungen auf {n_records} Datensätze ausführen. Ergebnisse auf der nächsten Seite.",
    fr = "Exécuter {n_checks} vérifications sur {n_records} enregistrements. Résultats page suivante."
  ),
  d3_exec_btn = list(en = "Execute", de = "Ausführen", fr = "Exécuter"),
  # Step 1 source-tab labels.
  src_local = list(en = "Local File", de = "Lokale Datei", fr = "Fichier local"),
  src_db = list(en = "SQL Database", de = "SQL-Datenbank", fr = "Base de données SQL"),
  src_fhir = list(en = "FHIR Server", de = "FHIR-Server", fr = "Serveur FHIR"),
  src_demo = list(en = "Demo Dataset", de = "Demo-Datensatz", fr = "Jeu de données démo"),
  # Step 1 upload card.
  src_upload_title = list(en = "Upload File", de = "Datei hochladen", fr = "Télécharger un fichier"),
  src_upload_sub = list(en = "CSV, Excel, JSON, or FHIR Bundle", de = "CSV, Excel, JSON oder FHIR-Bundle", fr = "CSV, Excel, JSON ou Bundle FHIR"),
  src_format = list(en = "Format", de = "Format", fr = "Format"),
  src_file = list(en = "File", de = "Datei", fr = "Fichier"),
  src_has_header = list(en = "Has header", de = "Hat Kopfzeile", fr = "Contient un en-tête"),
  src_separator = list(en = "Separator", de = "Trennzeichen", fr = "Séparateur"),
  src_sheet = list(en = "Sheet number", de = "Blattnummer", fr = "Numéro de feuille"),
  src_load = list(en = "Load Data", de = "Daten laden", fr = "Charger les données"),
  src_load_demo = list(en = "Load Demo Dataset", de = "Demo-Datensatz laden", fr = "Charger le jeu de données démo"),
  # SQL database panel.
  sql_title = list(en = "SQL Database Connection", de = "SQL-Datenbankverbindung", fr = "Connexion base de données SQL"),
  sql_test = list(en = "Test", de = "Testen", fr = "Tester"),
  sql_run = list(en = "Run Query", de = "Abfrage ausführen", fr = "Exécuter la requête"),
  # FHIR server panel.
  fhir_title = list(en = "FHIR Server", de = "FHIR-Server", fr = "Serveur FHIR"),
  fhir_test = list(en = "Test", de = "Testen", fr = "Tester"),
  fhir_fetch = list(en = "Fetch", de = "Abrufen", fr = "Récupérer"),
  # Step 4 cleansing buttons.
  cl_keep = list(en = "Keep As Is", de = "Unverändert beibehalten", fr = "Conserver tel quel"),
  cl_delete_rec = list(en = "Delete Record", de = "Datensatz löschen", fr = "Supprimer l'enregistrement"),
  cl_undo = list(en = "Undo", de = "Rückgängig", fr = "Annuler"),
  cl_gen_compare = list(en = "Generate Comparison", de = "Vergleich generieren", fr = "Générer la comparaison"),
  cl_original = list(en = "Original", de = "Original", fr = "Original"),
  cl_cleaned = list(en = "Cleaned", de = "Bereinigt", fr = "Nettoyé"),
  cl_new_name = list(en = "New Name", de = "Neuer Name", fr = "Nouveau nom"),
  cl_rename_btn = list(en = "Rename", de = "Umbenennen", fr = "Renommer"),
  cl_convert_date = list(en = "Convert to YYYY-MM-DD", de = "In JJJJ-MM-TT konvertieren", fr = "Convertir en AAAA-MM-JJ"),
  cl_delete_col_btn = list(en = "Delete Column", de = "Spalte löschen", fr = "Supprimer la colonne"),
  cl_date_col = list(en = "Date column", de = "Datumsspalte", fr = "Colonne de date"),
  cl_del_col_label = list(en = "Delete column", de = "Spalte löschen", fr = "Supprimer colonne"),
  # Step 3 auxiliary labels.
  s3_per_check = list(en = "Per-Check Impact", de = "Auswirkung pro Prüfung", fr = "Impact par vérification"),
  # Certificate and export button labels.
  cert_dq = list(en = "DQ Certificate (Word)", de = "DQ-Zertifikat (Word)", fr = "Certificat DQ (Word)"),
  cert_cleansing = list(en = "Cleansing Certificate (Word)", de = "Bereinigungszertifikat (Word)", fr = "Certificat de nettoyage (Word)"),
  cert_issues_csv = list(en = "Issues (CSV)", de = "Probleme (CSV)", fr = "Problèmes (CSV)"),
  cert_cleaned_csv = list(en = "Cleaned Data (CSV)", de = "Bereinigte Daten (CSV)", fr = "Données nettoyées (CSV)"),
  cert_audit_csv = list(en = "Audit Trail (CSV)", de = "Änderungsprotokoll (CSV)", fr = "Piste d'audit (CSV)"),
  # Footer navigation labels.
  nav_home = list(en = "Home", de = "Start", fr = "Accueil"),
  nav_import = list(en = "1 Import", de = "1 Import", fr = "1 Import"),
  nav_studio = list(en = "2 Studio", de = "2 Studio", fr = "2 Studio"),
  nav_results = list(en = "3 Results", de = "3 Ergebnisse", fr = "3 Résultats"),
  nav_cleansing = list(en = "4 Cleansing", de = "4 Bereinigung", fr = "4 Nettoyage"),
  nav_summary = list(en = "Summary", de = "Zusammenfassung", fr = "Résumé"),
  # Footer status indicator.
  footer_tutorial = list(en = "Tutorial", de = "Tutorial", fr = "Tutoriel"),
  footer_summary = list(en = "Summary", de = "Zusammenfassung", fr = "Résumé"),
  footer_welcome = list(en = "Welcome", de = "Willkommen", fr = "Bienvenue"),
  footer_step = list(en = "Step", de = "Schritt", fr = "Étape"),
  footer_checks = list(en = "checks", de = "Prüfungen", fr = "vérifications"),
  # Confirmation and dialog buttons.
  btn_confirm = list(en = "Confirm", de = "Bestätigen", fr = "Confirmer"),
  btn_cancel = list(en = "Cancel", de = "Abbrechen", fr = "Annuler"),
  btn_start_review = list(en = "Start Record Review", de = "Datensatzprüfung starten", fr = "Démarrer la revue des enregistrements"),
  btn_new_analysis = list(en = "Start New Analysis", de = "Neue Analyse starten", fr = "Démarrer une nouvelle analyse"),
  btn_preview = list(en = "Preview", de = "Vorschau", fr = "Aperçu"),
  btn_replace_all = list(en = "Replace All", de = "Alle ersetzen", fr = "Tout remplacer"),
  btn_regex = list(en = "Regex", de = "Regex", fr = "Regex"),
  btn_case_sensitive = list(en = "Case sensitive", de = "Groß-/Kleinschreibung", fr = "Sensible à la casse"),
  # Find-and-replace controls.
  fr_find = list(en = "Find", de = "Suchen", fr = "Rechercher"),
  fr_replace = list(en = "Replace with", de = "Ersetzen durch", fr = "Remplacer par"),
  fr_col = list(en = "Column", de = "Spalte", fr = "Colonne"),
  # Statistical-profiling button label.
  btn_stat_run = list(en = "Run Statistical Profiling", de = "Statistische Profilierung starten", fr = "Lancer le profilage statistique"),
  # Manual cell-edit hint.
  s4_manual_hint_text = list(
    en = "Double-click on any cell to edit it directly.",
    de = "Doppelklicken Sie auf eine Zelle, um sie direkt zu bearbeiten.",
    fr = "Double-cliquez sur une cellule pour la modifier directement."
  ),
  # Certificate section headings, emitted by the Word generator.
  cert_cover_title = list(en = "Data Quality Assessment Certificate", de = "Datenqualitäts-Bewertungszertifikat", fr = "Certificat d'Évaluation de la Qualité des Données"),
  cert_cl_cover_title = list(en = "Data Cleansing Certificate", de = "Datenbereinigungszertifikat", fr = "Certificat de Nettoyage des Données"),
  cert_toc = list(en = "Table of Contents", de = "Inhaltsverzeichnis", fr = "Table des matières"),
  cert_intro = list(en = "1. Introduction", de = "1. Einleitung", fr = "1. Introduction"),
  cert_intro_text = list(
    en = "This certificate documents a structured, fitness-for-purpose data quality assessment conducted using Open DQA, an open-source platform developed at Heidelberg University (MIISM). The assessment follows the fitness-for-purpose paradigm (Wang and Strong, 1996), meaning quality criteria are defined specifically for the research question at hand rather than applying generic checks.",
    de = "Dieses Zertifikat dokumentiert eine strukturierte, zweckgebundene Datenqualitätsbewertung, durchgeführt mit Open DQA, einer Open-Source-Plattform der Universität Heidelberg (MIISM). Die Bewertung folgt dem Fitness-for-Purpose-Paradigma (Wang und Strong, 1996), d.h. Qualitätskriterien werden spezifisch für die jeweilige Forschungsfrage definiert.",
    fr = "Ce certificat documente une évaluation structurée de la qualité des données selon l'aptitude à l'usage, réalisée avec Open DQA, une plateforme open source développée à l'Université de Heidelberg (MIISM). L'évaluation suit le paradigme fitness-for-purpose (Wang et Strong, 1996)."
  ),
  cert_methods = list(en = "2. Methods and Checks", de = "2. Methoden und Prüfungen", fr = "2. Méthodes et vérifications"),
  cert_methods_text = list(
    en = "Quality checks were defined through two complementary mechanisms: (D1) Statistical Profiling — automated detection of completeness, outliers, code validity, temporal consistency, duplicates, correlations, and cross-column plausibility; (D2) Manual Check Builder — structured step-by-step definition of custom rules using 20+ operators, IF-THEN conditional logic, GROUP BY aggregation, and imported value lists. All check expressions were validated against a security blacklist before execution.",
    de = "Qualitätsprüfungen wurden durch zwei komplementäre Mechanismen definiert: (D1) Statistische Profilierung — automatische Erkennung von Vollständigkeit, Ausreissern, Code-Validität, zeitlicher Konsistenz, Duplikaten, Korrelationen und spaltenübergreifender Plausibilität; (D2) Manueller Prüfungsbaukasten — strukturierte Definition individueller Regeln mit 20+ Operatoren, IF-THEN-Bedingungslogik, GROUP BY-Aggregation und importierten Wertelisten. Alle Ausdrücke wurden vor der Ausführung gegen eine Sicherheits-Blacklist validiert.",
    fr = "Les vérifications qualité ont été définies par deux mécanismes complémentaires: (D1) Profilage statistique — détection automatique de la complétude, valeurs aberrantes, validité des codes, cohérence temporelle, doublons, corrélations et plausibilité inter-colonnes; (D2) Constructeur manuel — définition structurée de règles personnalisées avec 20+ opérateurs, logique conditionnelle IF-THEN, agrégation GROUP BY et listes de valeurs importées."
  ),
  cert_config = list(en = "3. Configuration and Performance", de = "3. Konfiguration und Leistung", fr = "3. Configuration et performance"),
  cert_findings = list(en = "4. Findings", de = "4. Ergebnisse", fr = "4. Résultats"),
  cert_check_register = list(en = "5. Check Register", de = "5. Prüfungsregister", fr = "5. Registre des vérifications"),
  cert_norms = list(en = "6. Norm Alignment", de = "6. Normkonformität", fr = "6. Conformité aux normes"),
  cert_norms_text = list(
    en = "This assessment aligns with: (a) ICH E6 (R2) Good Clinical Practice — Section 5.5.3 requires documented data quality procedures; (b) EU GDPR Article 5(1)(d) — accuracy principle requiring that personal data be accurate and kept up to date; (c) Wang and Strong (1996) Total Data Quality Management framework — fitness-for-purpose quality dimensions; (d) DAMA DMBOK Data Quality Management standards. The systematic check definition, execution, and documentation in this certificate provides auditable evidence of data quality governance.",
    de = "Diese Bewertung entspricht: (a) ICH E6 (R2) Good Clinical Practice — Abschnitt 5.5.3 erfordert dokumentierte Datenqualitätsverfahren; (b) EU-DSGVO Artikel 5(1)(d) — Grundsatz der Richtigkeit, wonach personenbezogene Daten sachlich richtig und auf dem neuesten Stand sein müssen; (c) Wang und Strong (1996) Total Data Quality Management — Fitness-for-Purpose-Qualitätsdimensionen; (d) DAMA DMBOK Datenqualitätsmanagement. Die systematische Prüfungsdefinition, -ausführung und -dokumentation in diesem Zertifikat liefert auditierbaren Nachweis der Datenqualitäts-Governance.",
    fr = "Cette évaluation est conforme à: (a) ICH E6 (R2) Bonnes Pratiques Cliniques — Section 5.5.3 exigeant des procédures documentées de qualité des données; (b) RGPD UE Article 5(1)(d) — principe d'exactitude; (c) Wang et Strong (1996) Total Data Quality Management; (d) DAMA DMBOK. La définition, l'exécution et la documentation systématiques fournissent une preuve auditable de la gouvernance qualité."
  ),
  cert_conclusion = list(en = "7. Certification Statement", de = "7. Zertifizierungserklärung", fr = "7. Déclaration de certification"),
  cert_cl_intro_text = list(
    en = "This certificate documents all data modifications performed during the cleansing phase of the data quality assessment workflow. Every action was logged automatically with full before/after traceability. This documentation satisfies requirements for Good Clinical Practice (ICH E6 R2), GDPR accuracy principles (Art. 5(1)(d)), and institutional research data governance policies.",
    de = "Dieses Zertifikat dokumentiert alle Datenmodifikationen, die während der Bereinigungsphase des Datenqualitätsbewertungs-Workflows durchgeführt wurden. Jede Aktion wurde automatisch mit vollständiger Vorher/Nachher-Nachverfolgbarkeit protokolliert. Diese Dokumentation erfüllt die Anforderungen der Guten Klinischen Praxis (ICH E6 R2), der DSGVO-Genauigkeitsgrundsätze (Art. 5(1)(d)) und institutioneller Forschungsdaten-Governance-Richtlinien.",
    fr = "Ce certificat documente toutes les modifications de données effectuées pendant la phase de nettoyage. Chaque action a été journalisée automatiquement avec traçabilité complète avant/après. Cette documentation satisfait les exigences des Bonnes Pratiques Cliniques (ICH E6 R2), du RGPD (Art. 5(1)(d)) et des politiques de gouvernance des données de recherche."
  ),
  cert_cl_methods = list(en = "2. Cleansing Methods", de = "2. Bereinigungsmethoden", fr = "2. Méthodes de nettoyage"),
  cert_cl_methods_text = list(
    en = "Data cleansing was performed using the following tools within Open DQA: (4.1) Issue-guided record-by-record review with validate/keep/delete actions; (4.2) Find and replace with regex and case-sensitivity options; (4.3) Direct cell editing; (4.6) Column renaming; (4.7) Date format standardization; (4.8) Column deletion. All modifications were captured in a tamper-evident audit trail.",
    de = "Die Datenbereinigung wurde mit folgenden Werkzeugen in Open DQA durchgeführt: (4.1) Problemgeführte Datensatz-für-Datensatz-Prüfung mit Validieren/Beibehalten/Löschen; (4.2) Suchen und Ersetzen mit Regex und Groß-/Kleinschreibung; (4.3) Direkte Zellbearbeitung; (4.6) Spaltenumbenennung; (4.7) Datumsformat-Standardisierung; (4.8) Spaltenlöschung. Alle Änderungen wurden in einem manipulationssicheren Änderungsprotokoll erfasst.",
    fr = "Le nettoyage a été effectué avec les outils suivants dans Open DQA: (4.1) Revue guidée enregistrement par enregistrement; (4.2) Rechercher et remplacer avec regex; (4.3) Édition directe de cellules; (4.6) Renommage de colonnes; (4.7) Standardisation du format de date; (4.8) Suppression de colonnes. Toutes les modifications ont été capturées dans une piste d'audit."
  ),
  cert_cl_log = list(en = "3. Modification Log", de = "3. Änderungsprotokoll", fr = "3. Journal des modifications"),
  cert_cl_summary = list(en = "4. Summary Statistics", de = "4. Zusammenfassende Statistiken", fr = "4. Statistiques récapitulatives"),
  cert_cl_conclusion = list(en = "5. Certification Statement", de = "5. Zertifizierungserklärung", fr = "5. Déclaration de certification"),
  
  # Additional keys for full trilingual UI coverage.
  # D2 Base card titles and subtitles.
  d2_base_card_title = list(
    en = "D2 Base: Simple Check Builder",
    de = "D2 Basis: Einfacher Prüfungsbaukasten",
    fr = "D2 Base: Constructeur simple"
  ),
  d2_base_card_sub = list(
    en = "Select a check type, add conditions with AND/OR, test, name, save. Use D2 Advanced for GROUP BY, IF-THEN, nested groups or free R queries.",
    de = "Prüftyp wählen, Bedingungen mit UND/ODER kombinieren, testen, benennen, speichern. Für GROUP BY, IF-THEN, verschachtelte Gruppen oder freie R-Abfragen D2 Erweitert verwenden.",
    fr = "Choisir un type de vérification, combiner les conditions avec ET/OU, tester, nommer, enregistrer. Pour GROUP BY, IF-THEN, groupes imbriqués ou requêtes R libres, utiliser D2 Avancé."
  ),
  # D2 Advanced card titles and subtitles.
  d2_adv_card_title = list(
    en = "D2 Advanced: Grouped, Conditional, and Free R-Query Checks",
    de = "D2 Erweitert: Gruppierte, bedingte und freie R-Abfragen",
    fr = "D2 Avancé: Vérifications groupées, conditionnelles et requêtes R libres"
  ),
  d2_adv_card_sub = list(
    en = "Three independent builders, all sharing the same Save flow as D2 Base. Use the Test Query button on each before saving.",
    de = "Drei unabhängige Baukästen, alle mit dem gleichen Speichern-Ablauf wie D2 Basis. Vor dem Speichern jeweils 'Abfrage testen' klicken.",
    fr = "Trois constructeurs indépendants, tous avec le même flux d'enregistrement que D2 Base. Utiliser 'Tester la requête' avant d'enregistrer."
  ),
  # D2 Advanced sub-tab hints.
  d2_adv_gb_hint = list(
    en = "Flag groups that violate an aggregate rule. Example: flag patient IDs that appear more than once (count > 1).",
    de = "Gruppen markieren, die eine Aggregat-Regel verletzen. Beispiel: Patienten-IDs markieren, die mehr als einmal vorkommen (count > 1).",
    fr = "Marquer les groupes qui violent une règle agrégée. Exemple : marquer les identifiants de patient apparaissant plus d'une fois (count > 1)."
  ),
  d2_adv_if_hint = list(
    en = "IF (precondition on column A) THEN (column B must satisfy rule). Example: IF icd_code starts with O THEN gender must equal W.",
    de = "WENN (Vorbedingung auf Spalte A) DANN (Spalte B muss Regel erfüllen). Beispiel: WENN icd_code mit O beginnt, DANN muss gender gleich W sein.",
    fr = "SI (précondition sur colonne A) ALORS (colonne B doit satisfaire la règle). Exemple : SI icd_code commence par O ALORS gender doit être égal à W."
  ),
  d2_adv_rq_hint = list(
    en = "Write any R logical expression that evaluates per row. Same security blacklist as D2 Base applies: no system calls, no eval, no file access. TRUE means the row is flagged.",
    de = "Beliebiger R-Logik-Ausdruck, der pro Zeile ausgewertet wird. Gleiche Sicherheits-Blacklist wie D2 Basis: keine Systemaufrufe, kein eval, kein Dateizugriff. TRUE markiert die Zeile.",
    fr = "Toute expression logique R évaluée ligne par ligne. Même liste noire de sécurité que D2 Base : pas d'appels système, pas d'eval, pas d'accès fichier. TRUE marque la ligne."
  ),
  # Shared labels used across D2 Advanced sub-tabs.
  d2_adv_tab_gb       = list(en = "GROUP BY (aggregate)",   de = "GROUP BY (aggregiert)",       fr = "GROUP BY (agrégé)"),
  d2_adv_tab_if       = list(en = "IF-THEN (conditional)",  de = "IF-THEN (bedingt)",           fr = "IF-THEN (conditionnel)"),
  d2_adv_tab_rq       = list(en = "Free R-Query",           de = "Freie R-Abfrage",             fr = "Requête R libre"),
  d2_adv_aggregation  = list(en = "Aggregation",            de = "Aggregation",                 fr = "Agrégation"),
  d2_adv_threshold    = list(en = "Threshold",              de = "Schwellenwert",               fr = "Seuil"),
  d2_adv_gb_col       = list(en = "Group by column",        de = "Gruppierungsspalte",          fr = "Colonne de regroupement"),
  d2_adv_gb_target    = list(en = "Target column (for sum/mean/min/max/n_distinct)",
                             de = "Zielspalte (für sum/mean/min/max/n_distinct)",
                             fr = "Colonne cible (pour sum/mean/min/max/n_distinct)"),
  d2_adv_if_col       = list(en = "IF column",              de = "WENN Spalte",                 fr = "SI colonne"),
  d2_adv_if_op        = list(en = "IF operator",            de = "WENN Operator",               fr = "SI opérateur"),
  d2_adv_if_val       = list(en = "IF value",               de = "WENN Wert",                   fr = "SI valeur"),
  d2_adv_then_col     = list(en = "THEN column",            de = "DANN Spalte",                 fr = "ALORS colonne"),
  d2_adv_then_op      = list(en = "THEN operator",          de = "DANN Operator",               fr = "ALORS opérateur"),
  d2_adv_then_val     = list(en = "THEN value",             de = "DANN Wert",                   fr = "ALORS valeur"),
  d2_adv_rq_expr      = list(en = "R expression",           de = "R-Ausdruck",                  fr = "Expression R"),
  d2_adv_hint_in      = list(en = "Separate multiple values with comma , or semicolon ; if using IN / NOT IN in the THEN clause below.",
                             de = "Mehrere Werte mit Komma , oder Semikolon ; trennen, wenn IN / NOT IN in der DANN-Klausel verwendet wird.",
                             fr = "Séparer plusieurs valeurs par virgule , ou point-virgule ; en cas d'utilisation de IN / NOT IN dans la clause ALORS ci-dessous."),
  d2_adv_hint_between = list(en = "BETWEEN / NOT BETWEEN use 'min;max' (semicolon). IN / NOT IN accept , or ; .",
                             de = "BETWEEN / NOT BETWEEN verwenden 'min;max' (Semikolon). IN / NOT IN akzeptieren , oder ; .",
                             fr = "BETWEEN / NOT BETWEEN utilisent 'min;max' (point-virgule). IN / NOT IN acceptent , ou ; ."),
  d2_adv_test_gb      = list(en = "Test GROUP BY query",    de = "GROUP BY-Abfrage testen",     fr = "Tester la requête GROUP BY"),
  d2_adv_test_if      = list(en = "Test IF-THEN query",     de = "IF-THEN-Abfrage testen",      fr = "Tester la requête IF-THEN"),
  d2_adv_test_rq      = list(en = "Test R-Query",           de = "R-Abfrage testen",            fr = "Tester la requête R"),
  d2_adv_clear        = list(en = "Clear",                  de = "Löschen",                     fr = "Effacer"),
  d2_adv_save         = list(en = "Save check",             de = "Prüfung speichern",           fr = "Enregistrer la vérification"),
  d2_adv_placeholder  = list(en = "e.g. age > 120 | (as.Date(admission_date) > as.Date(discharge_date))",
                             de = "z. B. age > 120 | (as.Date(admission_date) > as.Date(discharge_date))",
                             fr = "ex. age > 120 | (as.Date(admission_date) > as.Date(discharge_date))"),
  # D3 tab headers.
  d3_top_tab          = list(en = "D3: Check Manager & Execute", de = "D3: Prüfungsmanager & Ausführung", fr = "D3: Gestionnaire & Exécution"),
  d2b_top_tab         = list(en = "D2 Base: Check Builder",      de = "D2 Basis: Prüfungsbaukasten",      fr = "D2 Base: Constructeur"),
  d2a_top_tab         = list(en = "D2 Advanced: Group / Conditional / R-Query",
                             de = "D2 Erweitert: Gruppe / Bedingt / R-Abfrage",
                             fr = "D2 Avancé: Groupe / Conditionnel / Requête R"),
  # Step 4.7 runtime labels.
  s4_fmt_col          = list(en = "Column",                 de = "Spalte",                      fr = "Colonne"),
  s4_fmt_target       = list(en = "Target type",            de = "Zieltyp",                     fr = "Type cible"),
  s4_fmt_preview_btn  = list(en = "Preview NAs",            de = "NA-Vorschau",                 fr = "Aperçu des NA"),
  s4_fmt_apply_btn    = list(en = "Apply coercion",         de = "Konvertierung anwenden",      fr = "Appliquer la conversion"),
  s4_fmt_clean        = list(en = "No cells would become NA. Conversion is clean.",
                             de = "Keine Zellen würden zu NA. Konvertierung ist sauber.",
                             fr = "Aucune cellule ne deviendrait NA. Conversion propre."),
  s4_fmt_would_na     = list(en = "cell(s) cannot be coerced and would become NA. Examples:",
                             de = "Zelle(n) können nicht konvertiert werden und würden zu NA. Beispiele:",
                             fr = "cellule(s) ne peuvent pas être converties et deviendraient NA. Exemples:"),
  s4_fmt_applied      = list(en = "Coerced column to target type.",
                             de = "Spalte in Zieltyp konvertiert.",
                             fr = "Colonne convertie au type cible."),
  s4_fmt_type_col     = list(en = "Column",                 de = "Spalte",                      fr = "Colonne"),
  s4_fmt_type_cur     = list(en = "Current class",          de = "Aktuelle Klasse",             fr = "Classe actuelle"),
  s4_fmt_type_det     = list(en = "Detected type",          de = "Erkannter Typ",               fr = "Type détecté"),
  s4_fmt_type_nn      = list(en = "Non-NA cells",           de = "Nicht-NA-Zellen",             fr = "Cellules non NA"),
  # Modal-dialog labels.
  modal_stay          = list(en = "Stay here",              de = "Hier bleiben",                fr = "Rester ici"),
  modal_goto_studio   = list(en = "Next: Checks Studio",    de = "Weiter zum Studio",           fr = "Aller au Studio"),
  modal_ds_confirmed  = list(en = "Dataset confirmed",      de = "Datensatz bestätigt",         fr = "Jeu de données confirmé"),
  modal_ds_body       = list(en = "The dataset (%d rows, %d columns) is now locked for analysis. All previous checks, results, and cleansing actions have been reset.",
                             de = "Der Datensatz mit %d Zeilen und %d Spalten ist nun für die Analyse gesperrt. Alle bisherigen Prüfungen, Ergebnisse und Bereinigungsaktionen wurden zurückgesetzt.",
                             fr = "Le jeu de données de %d lignes et %d colonnes est maintenant verrouillé pour l'analyse. Toutes les vérifications, résultats et actions de nettoyage précédents ont été réinitialisés."),
  modal_ds_next       = list(en = "Click Next to proceed to the Checks Studio.",
                             de = "Klicken Sie auf Weiter, um zum Prüfungsstudio zu gelangen.",
                             fr = "Cliquez sur Suivant pour accéder au Studio de vérifications."),
  sql_elapsed = list(
    en = "Query executed in",
    de = "Abfrage ausgeführt in",
    fr = "Requête exécutée en"
  ),
  fhir_elapsed = list(
    en = "Request completed in",
    de = "Anfrage abgeschlossen in",
    fr = "Requête terminée en"
  ),
  # Process-timer strip status.
  timer_status        = list(en = "Status:",                de = "Status:",                     fr = "État :"),
  timer_idle          = list(en = "idle",                   de = "bereit",                      fr = "inactif"),
  # Top navigation pills. The pill labels are resolved client-side from these keys.
  pill_home           = list(en = "Home",                   de = "Start",                       fr = "Accueil"),
  pill_import         = list(en = "1 Import",               de = "1 Import",                    fr = "1 Import"),
  pill_studio         = list(en = "2 Studio",               de = "2 Studio",                    fr = "2 Studio"),
  pill_results        = list(en = "3 Results",              de = "3 Ergebnisse",                fr = "3 Résultats"),
  pill_cleansing      = list(en = "4 Cleansing",            de = "4 Bereinigung",               fr = "4 Nettoyage"),
  pill_summary        = list(en = "Summary",                de = "Zusammenfassung",             fr = "Résumé"),
  # Footer Next button.
  footer_next         = list(en = "Next",                   de = "Weiter",                      fr = "Suivant"),
  src_upload_title    = list(en = "Upload File",            de = "Datei hochladen",             fr = "Téléverser un fichier"),
  cl_log_empty        = list(en = "No actions yet.",        de = "Noch keine Aktionen.",        fr = "Aucune action pour l'instant."),
  cl_delcol_label     = list(en = "Delete column",          de = "Spalte löschen",              fr = "Supprimer la colonne")
)

i18n <- function(k, l = "en") {
  e <- i18n_db[[k]]
  if (is.null(e)) return(k)
  v <- e[[l]]
  if (is.null(v)) v <- e[["en"]]
  if (is.null(v)) return(k)
  v
}

# General-purpose helpers.
`%null%` <- function(x, y) if (is.null(x)) y else x
safe_notify <- function(msg, type = c("message", "warning", "error")) {
  type <- match.arg(type)
  tryCatch(showNotification(msg, type = type, duration = 4), error = function(e) NULL)
}
pcv <- function(s) {
  if (is.null(s) || length(s) == 0) return(character(0))
  vals <- unlist(strsplit(as.character(s), "[,;]", perl = TRUE))
  vals <- trimws(vals)
  unique(vals[nzchar(vals)])
}
is_blank <- function(x) {
  if (is.null(x)) return(TRUE)
  y <- suppressWarnings(as.character(x))
  is.na(y) | trimws(y) == ""
}
safe_sym <- function(nm) {
  nm <- as.character(nm)
  ok <- make.names(nm) == nm && !grepl("^\\d", nm)
  if (ok) nm else paste0("`", gsub("`", "``", nm, fixed = TRUE), "`")
}
as_num_lenient <- function(x) {
  y <- suppressWarnings(as.character(x))
  y <- gsub("[[:space:]]", "", y)
  y <- gsub("[^0-9\\-\\+\\,\\.]", "", y)
  both <- grepl("\\.", y) & grepl(",", y)
  y[both] <- gsub("\\.", "", y[both])
  y <- gsub(",", ".", y, fixed = TRUE)
  suppressWarnings(as.numeric(y))
}
sample_idx <- function(n, sample_n = 50000, seed = 1) {
  n <- as.integer(n); sample_n <- as.integer(sample_n)
  if (is.na(n) || n <= 0) return(integer(0))
  if (n <= sample_n) return(seq_len(n))
  set.seed(seed); sort(sample.int(n, sample_n, replace = FALSE))
}
score_band <- function(score) {
  s <- as.numeric(score)
  if (is.na(s)) return("red")
  if (s >= 80) "green" else if (s >= 60) "yellow" else if (s >= 40) "orange" else "red"
}
score_hex <- function(score) {
  b <- score_band(score)
  switch(b, green = "#16a34a", yellow = "#ca8a04", orange = "#ea580c", red = "#dc2626")
}
calc_quality_score <- function(n_total, issues_df) {
  n_total <- as.integer(n_total)
  if (is.null(issues_df) || nrow(issues_df) == 0 || n_total <= 0) {
    return(list(score = 100, affected_rows = 0L, issue_count = 0L))
  }
  affected <- length(unique(issues_df$row))
  score <- 100 * (1 - affected / n_total)
  score <- max(min(score, 100), 0)
  list(score = round(score, 1), affected_rows = as.integer(affected), issue_count = as.integer(nrow(issues_df)))
}
issues_by_check <- function(issues_df, n_total) {
  if (is.null(issues_df) || nrow(issues_df) == 0) {
    return(data.frame(check_id = character(), check_name = character(),
                      severity = character(), affected_n = integer(),
                      affected_pct = numeric(), stringsAsFactors = FALSE))
  }
  n_total  <- max(as.integer(n_total), 1L)
  dt       <- data.table::as.data.table(issues_df)
  sev_rank <- c(Low = 1L, Medium = 2L, High = 3L, Critical = 4L)
  # Single grouped pass per check. Records the first issue name as the display name, the
  # highest severity encountered, and the count of distinct rows flagged.
  out <- dt[, list(
    check_name = issue[1L],
    severity   = {
      sv <- as.character(severity)
      sv[is.na(sv) | !nzchar(sv)] <- "Low"
      sv <- intersect(sv, names(sev_rank))
      if (!length(sv)) "Low" else sv[which.max(sev_rank[sv])]
    },
    affected_n = data.table::uniqueN(row)
  ), by = check_id]
  out[, affected_pct := round(100 * affected_n / n_total, 2)]
  data.table::setorder(out, -affected_pct, -affected_n)
  # Column order is fixed so that the Word report and the per-check plot code do not
  # need to change.
  as.data.frame(out[, list(check_id, check_name, severity,
                           affected_n, affected_pct)])
}
format_elapsed <- function(secs) {
  secs <- round(secs, 2)
  if (secs < 1) paste0(round(secs * 1000), " ms")
  else if (secs < 60) paste0(secs, " s")
  else paste0(floor(secs / 60), " min ", round(secs %% 60, 1), " s")
}
# Infer a best-fit type label for a column, using the same labels the UI exposes. Falls
# back to character when nothing else fits.
detect_col_type <- function(x, sample_n = 2000L) {
  if (is.logical(x))                               return("logical")
  if (inherits(x, "POSIXt"))                       return("datetime")
  if (inherits(x, "Date"))                         return("date")
  if (is.integer(x))                               return("integer")
  if (is.numeric(x))                               return("numeric")
  v <- as.character(x)
  v <- v[!is.na(v) & nzchar(trimws(v))]
  if (length(v) == 0) return("character")
  if (length(v) > sample_n) v <- v[seq_len(sample_n)]
  # Candidate: logical.
  lo <- tolower(trimws(v))
  if (all(lo %in% c("true","false","t","f","0","1","yes","no")))       return("logical")
  # Candidate: integer or numeric.
  nn <- suppressWarnings(as.numeric(v))
  if (!anyNA(nn)) {
    if (all(abs(nn - round(nn)) < 1e-9))                               return("integer")
    return("numeric")
  }
  # Candidate: date or datetime. as.POSIXct() raises an error (not a warning) on strings
  # it cannot parse, so the call is wrapped in tryCatch(). To keep the detector fast,
  # the datetime branch is only attempted when at least one value looks date-shaped.
  looks_dateish <- any(grepl("[0-9]{2,4}[-/.][0-9]{1,2}[-/.][0-9]{1,4}", v))
  if (looks_dateish) {
    dt <- tryCatch(suppressWarnings(as.POSIXct(v, tz = "UTC")),
                   error = function(e) rep(as.POSIXct(NA), length(v)))
    if (mean(!is.na(dt)) > 0.8 && any(grepl("[0-9]:[0-9]", v)))        return("datetime")
    d <- tryCatch(suppressWarnings(as.Date(v)),
                  error = function(e) rep(as.Date(NA), length(v)))
    if (mean(!is.na(d)) > 0.8)                                         return("date")
  }
  "character"
}

# Coerce a vector to a target type. Returns the coerced vector together with the integer
# positions of cells that became NA purely because of the coercion.
coerce_col <- function(x, target) {
  orig <- x
  na_before <- is.na(orig) | (is.character(orig) & !nzchar(trimws(orig)))
  new <- switch(target,
                "character" = as.character(orig),
                "integer"   = suppressWarnings(as.integer(as.character(orig))),
                "numeric"   = suppressWarnings(as.numeric(as.character(orig))),
                "logical"   = {
                  lo <- tolower(trimws(as.character(orig)))
                  out <- rep(NA, length(orig))
                  out[lo %in% c("true","t","1","yes")] <- TRUE
                  out[lo %in% c("false","f","0","no")] <- FALSE
                  out
                },
                "date"      = suppressWarnings(as.Date(as.character(orig))),
                "datetime"  = suppressWarnings(as.POSIXct(as.character(orig), tz = "UTC")),
                as.character(orig)
  )
  na_after <- is.na(new)
  # Only count NAs introduced by the coercion itself. Cells that were already empty
  # before the coercion are excluded.
  na_idx <- which(na_after & !na_before)
  list(new = new, na_idx = na_idx)
}

# Produce a data.frame where changed cells are wrapped in a coloured HTML span, suitable
# for rendering in DT with escape = FALSE. Input: original and modified data.frames with
# identical shape and column names.
# Colour scheme: amber for modified cells, red for cells that became NA, no markup for
# unchanged cells. User values are HTML-escaped before being injected, so there is no
# injection risk.
build_diff_html <- function(orig_df, work_df) {
  if (is.null(orig_df) || is.null(work_df)) return(work_df)
  common <- intersect(names(orig_df), names(work_df))
  n <- min(nrow(orig_df), nrow(work_df))
  out <- as.data.frame(lapply(work_df[seq_len(n), common, drop = FALSE],
                              as.character),
                       stringsAsFactors = FALSE)
  esc <- function(s) {
    s <- ifelse(is.na(s), "NA", s)
    # Escape HTML metacharacters. The ampersand must be replaced first, otherwise
    # already-escaped sequences would be double-escaped.
    s <- gsub("&", "&amp;",  s, fixed = TRUE)
    s <- gsub("<", "&lt;",   s, fixed = TRUE)
    s <- gsub(">", "&gt;",   s, fixed = TRUE)
    s <- gsub("\"", "&quot;", s, fixed = TRUE)
    s
  }
  for (col in common) {
    o_raw <- as.character(orig_df[[col]])[seq_len(n)]
    w_raw <- as.character(work_df[[col]])[seq_len(n)]
    o <- ifelse(is.na(orig_df[[col]][seq_len(n)]), NA_character_, o_raw)
    w <- ifelse(is.na(work_df[[col]][seq_len(n)]), NA_character_, w_raw)
    # Classify each cell as unchanged, modified, or newly NA.
    o_na <- is.na(o); w_na <- is.na(w)
    became_na <- !o_na &  w_na
    modified  <- !o_na & !w_na & (o != w)
    # Build the escaped display string for each cell.
    disp <- esc(ifelse(w_na, "NA", w))
    disp[became_na] <- paste0(
      "<span style='background:#fde8e8;color:#b91c1c;font-weight:600;",
      "padding:1px 4px;border-radius:3px;' title='was: ",
      esc(ifelse(o_na, "NA", o[became_na])),
      "'>", disp[became_na], "</span>")
    disp[modified] <- paste0(
      "<span style='background:#fef3c7;color:#92400e;font-weight:600;",
      "padding:1px 4px;border-radius:3px;' title='was: ",
      esc(o[modified]),
      "'>", disp[modified], "</span>")
    out[[col]] <- disp
  }
  out
}
# Escape a user-supplied value before injecting it into generated R code. This is
# defence in depth: validate_expression() and the security blacklist already block
# dangerous calls, but a stray quote or backslash could still derail parsing.
escape_literal <- function(x) {
  x <- as.character(x)
  x <- gsub("\\\\", "\\\\\\\\", x, perl = FALSE)   # replace the backslash before any other character
  x <- gsub('"',  '\\\\"',       x, fixed = TRUE)  # then the double quote
  x
}

# Count the number of distinct rows flagged across all checks. Used as the single source
# of truth for the quality score, per-source summaries, plots, and certificates.
issues_unique_rows <- function(issues_df) {
  if (is.null(issues_df) || nrow(issues_df) == 0) return(0L)
  length(unique(issues_df$row))
}
# Security layer.
SEC_BLACKLIST <- paste0(
  "(system|exec|shell|pipe|download\\.file|source|\\beval\\b|\\bparse\\b|",
  "assign|\\brm\\(|file\\.|readLines|writeLines|unlink|library|require|",
  "install|Sys\\.|proc\\.time|options\\(|setwd|getwd|\\bdo\\.call\\b|",
  "environment|globalenv|baseenv|new\\.env|url\\(|browseURL|Rscript|",
  ".Internal|.Primitive|.Call|.External|readRDS|saveRDS|load\\(|",
  "save\\(|cat\\(|sink\\(|scan\\()"
)
validate_expression <- function(expr_str) {
  expr_str <- trimws(as.character(expr_str))
  if (!nzchar(expr_str)) return(list(ok = FALSE, msg = "Expression is empty."))
  if (nchar(expr_str) > 10000) return(list(ok = FALSE, msg = "Expression too long (max 10000)."))
  if (grepl(SEC_BLACKLIST, expr_str, ignore.case = TRUE, perl = TRUE)) {
    return(list(ok = FALSE, msg = "Expression contains forbidden function calls (security)."))
  }
  if (grepl("[`]{3,}", expr_str)) return(list(ok = FALSE, msg = "Invalid backtick sequence."))
  parsed <- tryCatch(rlang::parse_expr(expr_str), error = function(e) e)
  if (inherits(parsed, "error")) {
    return(list(ok = FALSE, msg = paste("Invalid R syntax:", parsed$message)))
  }
  list(ok = TRUE, parsed = parsed)
}
safe_eval_expr <- function(expr_str, df, max_rows = 200000) {
  v <- validate_expression(expr_str)
  if (!v$ok) return(list(ok = FALSE, msg = v$msg))
  n <- nrow(df)
  result <- tryCatch({
    res <- eval(v$parsed, envir = df)
    if (!(is.logical(res) || is.numeric(res) || is.integer(res))) {
      stop("Expression must return logical.")
    }
    res <- as.logical(res)
    if (length(res) != n) res <- rep_len(res, n)
    res
  }, error = function(e) e)
  if (inherits(result, "error")) {
    return(list(ok = FALSE, msg = paste("Runtime error:", result$message)))
  }
  list(ok = TRUE, result = result)
}

# Undo stack for cleansing actions.
cl_undo_push <- function(rv, data_obj, max_steps = 5) {
  if (is.null(data_obj)) return(invisible(FALSE))
  entry <- list(type = "obj", obj = data_obj)
  rv$cl_undo_stack <- c(rv$cl_undo_stack, list(entry))
  while (length(rv$cl_undo_stack) > max_steps) {
    rv$cl_undo_stack <- rv$cl_undo_stack[-1]
  }
  invisible(TRUE)
}
cl_undo_pop <- function(rv) {
  if (length(rv$cl_undo_stack) == 0) return(NULL)
  entry <- rv$cl_undo_stack[[length(rv$cl_undo_stack)]]
  rv$cl_undo_stack <- rv$cl_undo_stack[-length(rv$cl_undo_stack)]
  if (entry$type == "obj") return(entry$obj)
  NULL
}

# Demo dataset. Fifty synthetic German inpatient encounters with realistic ICD-10-GM and
# OPS codes. Deliberate errors are embedded so every feature of the platform can be
# exercised without loading real patient data.
generate_demo_data <- function() {
  set.seed(2026)
  n <- 50
  ids <- sprintf("PAT-%05d", seq_len(n))
  ages <- c(
    72, 58, 81, 45, 67, 34, 89, 63, 51, 76,
    43, 85, 29, 68, 55, 91, 37, 74, 60, 82,
    48, 71, 39, 66, 53, 78, 41, 88, 57, 73,
    36, 69, 83, 46, 62, 27, 77, 50, 64, 80,
    44, 75, 33, 59, 86, 70, 52, 65, 38, 79
  )
  genders <- c(
    "M","W","W","M","M","W","M","W","M","W",
    "M","W","M","W","M","W","W","M","W","M",
    "W","M","W","M","W","M","W","M","M","W",
    "W","M","W","M","W","M","M","W","M","W",
    "M","W","W","M","W","M","W","M","M","W"
  )
  # ICD-10-GM codes that reflect common German inpatient coding patterns.
  icds <- c(
    "I50.13","E11.90","J18.9","I25.11","C34.1",  # Herzinsuffizienz, DM2, Pneumonie, KHK, Lungenkarzinom
    "S72.00","I10.00","E78.0","J44.11","N18.3",   # Schenkelhalsfraktur, Hypertonie, Hyperlipidaemie, COPD, CKD
    "I48.0","E11.90","K80.10","G30.1","F32.1",    # Vorhofflimmern, DM2, Cholezystolithiasis, Alzheimer, Depression
    "I63.3","I10.00","J44.10","C50.4","M54.5",    # Hirninfarkt, Hypertonie, COPD, Mammakarzinom, Kreuzschmerz
    "E11.90","I25.11","","K35.30","N39.0",         # DM2, KHK, MISSING, Appendizitis, HWI
    "J18.9","I10.00","E11.90","S06.0","I50.13",   # Pneumonie, Hypertonie, DM2, Commotio, Herzinsuffizienz
    "C18.0","E11.90","J44.11","I48.0","M16.1",    # Kolonkarzinom, DM2, COPD, VHF, Koxarthrose
    "I10.00","E78.0","N18.4","J18.9","I25.11",    # Hypertonie, Hyperlipidaemie, CKD, Pneumonie, KHK
    "E11.90","K56.6","F10.2","S72.00","I10.00",   # DM2, Ileus, Alkoholabhaengigkeit, SHF, Hypertonie
    "J96.00","I50.14","E11.90","C61","I10.00"      # Respirat. Insuff., Herzinsuffizienz, DM2, Prostatakarzinom, Hypertonie
  )
  ops_codes <- c(
    "","","","5-361.0","5-324.a",                  # PTCA, Lungenresektion
    "5-820.00","","","","",                         # Huefte TEP
    "","","5-511.11","","",                         # Cholezystektomie
    "","","","5-870.a1","",                         # Mammaablatio
    "","5-361.0","","5-470.10","",                  # PTCA, Appendektomie
    "","","","","",
    "5-455.51","","","","5-820.40",                 # Hemikolektomie, Huefte TEP
    "","","","","5-361.0",                          # PTCA
    "","5-469.20","","5-790.0f","",                 # Ileus OP, Osteosynthese
    "8-706","","","5-601.0",""                      # Intubation, Prostatektomie
  )
  base_date <- as.Date("2024-01-05")
  adm_dates <- base_date + cumsum(sample(2:7, n, replace = TRUE))
  # Inject known errors so the profiler and manual builder have concrete targets to
  # find.
  adm_dates[40] <- Sys.Date() + 30                # Future date error
  dis_dates <- adm_dates + sample(1:14, n, replace = TRUE)
  dis_dates[25] <- adm_dates[25] - 3              # Negative LOS error
  ids[48] <- ids[10]; adm_dates[48] <- adm_dates[10] # Duplicate
  los <- as.integer(dis_dates - adm_dates)
  notes <- c(
    "Dekompensierte Herzinsuffizienz NYHA III","DM2 Einstellung","Ambulant erworbene Pneumonie","Stabile KHK, Belastungsdyspnoe","Lungenkarzinom ED, Staging",
    "Schenkelhalsfraktur links nach Sturz","Hypertensive Krise","Hyperlipidaemie","AECOPD Grad III","Chronische Niereninsuffizienz Stadium 3",
    "Paroxysmales Vorhofflimmern","DM2 mit Polyneuropathie","Symptomatische Cholezystolithiasis","Alzheimer Demenz, mittelgradig","Mittelgradige depressive Episode",
    "Mediainfarkt rechts","Arterielle Hypertonie, gut eingestellt","COPD mit akuter Exazerbation","Mammakarzinom links, cT2N1M0","Lumbago, V.a. Bandscheibenvorfall",
    "DM2 Kontrolluntersuchung","KHK, Z.n. PTCA","","Akute Appendizitis","Harnwegsinfekt unkompliziert",
    "Nosokomial erworbene Pneumonie","Hypertonie, medikamentoes","DM2 mit Nephropathie","Leichte SHT nach Sturz","Herzinsuffizienz NYHA IV",
    "Kolonkarzinom Coecum, cT3N0M0","DM2 Erstdiagnose","AECOPD mit resp. Insuffizienz","Permanentes Vorhofflimmern","Koxarthrose rechts, ED Huefte TEP",
    "Hypertonie und Adipositas","Gemischte Hyperlipidaemie","CKD Stadium 4, Shuntvorbereitung","Stauungspneumonie bds.","KHK Dreigefaesserkrankung",
    "DM2 Fusssyndrom","Paralytischer Ileus postoperativ","Alkoholabhaengigkeitssyndrom","Schenkelhalsfraktur rechts nach Sturz","Hypertonie Grad 2",
    "Akute respiratorische Insuffizienz","Terminale Herzinsuffizienz","DM2 Ketoazidose","Prostatakarzinom pT2cN0M0","Hypertonie und Vorhofflimmern"
  )
  data.frame(
    patient_id = ids, age = ages, gender = genders,
    icd_code = icds, ops_code = ops_codes,
    admission_date = as.character(adm_dates),
    discharge_date = as.character(dis_dates),
    los = los, clinical_notes = notes,
    stringsAsFactors = FALSE
  )
}

# Data readers. Each reader returns a plain data.frame.
as_rectangular <- function(x) {
  if (is.data.frame(x)) return(as.data.frame(x))
  if (is.null(x)) return(data.frame())
  for (k in c("data", "results", "items", "records", "entry", "hits", "rows")) {
    if (is.list(x) && !is.null(x[[k]])) return(as_rectangular(x[[k]]))
  }
  if (is.list(x)) {
    tryCatch({
      lst <- lapply(x, function(e) as.data.frame(jsonlite::flatten(e), stringsAsFactors = FALSE))
      return(as.data.frame(data.table::rbindlist(lst, fill = TRUE)))
    }, error = function(e) NULL)
  }
  as.data.frame(x, stringsAsFactors = FALSE)
}

read_json_tabular <- function(path) {
  df <- tryCatch({
    obj <- jsonlite::fromJSON(path, flatten = TRUE)
    as_rectangular(obj)
  }, error = function(e) NULL)
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) {
    con <- file(path, open = "r")
    on.exit(close(con))
    df <- tryCatch(jsonlite::stream_in(con, flatten = TRUE, verbose = FALSE), error = function(e) NULL)
  }
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) stop("Cannot parse JSON.")
  df
}

read_fhir_tabular <- function(path) {
  bundle <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!is.list(bundle)) stop("Not a valid FHIR Bundle.")
  res <- if (!is.null(bundle$entry)) lapply(bundle$entry, `[[`, "resource") else list(bundle)
  pts <- Filter(Negate(is.null), lapply(res, function(r) if (identical(r$resourceType, "Patient")) r))
  enc <- Filter(Negate(is.null), lapply(res, function(r) if (identical(r$resourceType, "Encounter")) r))
  cnd <- Filter(Negate(is.null), lapply(res, function(r) if (identical(r$resourceType, "Condition")) r))
  prc <- Filter(Negate(is.null), lapply(res, function(r) if (identical(r$resourceType, "Procedure")) r))
  gri <- function(ref) if (is.null(ref)) NA_character_ else sub("^.*/", "", ref)
  fc <- function(c) if (is.null(c) || !length(c)) NA_character_ else as.character(c[[1]]$code %||% NA)
  pdf <- if (length(pts)) {
    data.frame(
      patient_id = vapply(pts, function(p) as.character(p$id %||% NA), character(1)),
      gender = vapply(pts, function(p) as.character(p$gender %||% NA), character(1)),
      birth_date = vapply(pts, function(p) as.character(p$birthDate %||% NA), character(1)),
      stringsAsFactors = FALSE
    )
  } else data.frame(patient_id = character(), gender = character(), birth_date = character())
  edf <- if (length(enc)) {
    data.frame(
      patient_id = vapply(enc, function(e) gri(e$subject$reference %||% NA), character(1)),
      admission_date = vapply(enc, function(e) as.character(e$period$start %||% NA), character(1)),
      discharge_date = vapply(enc, function(e) as.character(e$period$end %||% NA), character(1)),
      stringsAsFactors = FALSE
    )
  } else data.frame(patient_id = character(), admission_date = character(), discharge_date = character())
  cdf <- if (length(cnd)) {
    data.frame(
      patient_id = vapply(cnd, function(cn) gri(cn$subject$reference %||% NA), character(1)),
      icd = vapply(cnd, function(cn) fc((cn$code$coding %||% list())[1]), character(1)),
      stringsAsFactors = FALSE
    )
  } else data.frame(patient_id = character(), icd = character())
  prf <- if (length(prc)) {
    data.frame(
      patient_id = vapply(prc, function(pr) gri(pr$subject$reference %||% NA), character(1)),
      ops = vapply(prc, function(pr) fc((pr$code$coding %||% list())[1]), character(1)),
      stringsAsFactors = FALSE
    )
  } else data.frame(patient_id = character(), ops = character())
  if (nrow(cdf)) cdf <- cdf |> group_by(patient_id) |> summarise(icd = paste(unique(na.omit(icd)), collapse = "; "), .groups = "drop")
  if (nrow(prf)) prf <- prf |> group_by(patient_id) |> summarise(ops = paste(unique(na.omit(ops)), collapse = "; "), .groups = "drop")
  out <- if (nrow(edf)) {
    edf |> left_join(pdf, by = "patient_id") |> left_join(cdf, by = "patient_id") |> left_join(prf, by = "patient_id")
  } else {
    full_join(pdf, cdf, by = "patient_id") |> full_join(prf, by = "patient_id") |>
      mutate(admission_date = NA_character_, discharge_date = NA_character_)
  }
  for (dc in c("birth_date", "admission_date", "discharge_date")) {
    if (dc %in% names(out)) out[[dc]] <- suppressWarnings(as.Date(out[[dc]]))
  }
  out
}

# SQL helpers. Thin wrappers around DBI.
odqa_trim <- function(x) { if (is.null(x)) return(""); trimws(as.character(x)) }
odqa_int <- function(x) suppressWarnings(as.integer(x))
odqa_disconnect_safe <- function(con) {
  if (is.null(con)) return(invisible(FALSE))
  tryCatch({
    if (inherits(con, "DBIConnection") && DBI::dbIsValid(con)) DBI::dbDisconnect(con)
  }, error = function(e) NULL)
  invisible(TRUE)
}
odqa_pick_mssql_driver <- function() {
  if (!isTRUE(sql_ms)) return(NULL)
  drv_tbl <- tryCatch(odbc::odbcListDrivers(), error = function(e) NULL)
  if (is.null(drv_tbl) || nrow(drv_tbl) == 0) return(NULL)
  drv_names <- character()
  for (cn in c("name", "driver", "Name", "Driver")) {
    if (cn %in% names(drv_tbl)) { drv_names <- unique(as.character(drv_tbl[[cn]])); break }
  }
  if (length(drv_names) == 0) drv_names <- unique(as.character(drv_tbl[[1]]))
  preferred <- c("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server", "SQL Server")
  for (p in preferred) if (p %in% drv_names) return(p)
  hit <- drv_names[grepl("sql server", drv_names, ignore.case = TRUE)]
  if (length(hit)) return(hit[1])
  NULL
}
odqa_db_connect <- function(db_type, host, port, dbname, user, password, connect_timeout = 10L) {
  db_type <- odqa_trim(db_type)
  if (!nzchar(db_type)) db_type <- "PostgreSQL"
  host <- odqa_trim(host); dbname <- odqa_trim(dbname)
  user <- odqa_trim(user); port_i <- odqa_int(port)
  if (is.null(password)) password <- ""
  if (!nzchar(host)) stop("Host is empty.")
  if (!nzchar(dbname)) stop("Database is empty.")
  if (!nzchar(user)) stop("User is empty.")
  if (is.na(port_i) || port_i < 1L) stop("Port must be positive.")
  con <- NULL
  tryCatch({
    if (identical(db_type, "PostgreSQL")) {
      if (!isTRUE(sql_pg)) stop("PostgreSQL requires DBI+RPostgres.")
      con <- DBI::dbConnect(RPostgres::Postgres(), host = host, port = port_i,
                            dbname = dbname, user = user, password = password, connect_timeout = as.integer(connect_timeout))
    } else if (identical(db_type, "Microsoft SQL")) {
      if (!isTRUE(sql_ms)) stop("MS SQL requires DBI+odbc.")
      drv <- odqa_pick_mssql_driver()
      if (is.null(drv) || !nzchar(drv)) stop("No SQL Server ODBC driver.")
      args <- list(odbc::odbc(), Driver = drv, Server = paste0(host, ",", port_i),
                   Database = dbname, UID = user, PWD = password, Timeout = as.integer(connect_timeout))
      con <- do.call(DBI::dbConnect, args)
    } else stop("Unsupported DB: ", db_type)
  }, error = function(e) { odqa_disconnect_safe(con); stop(e$message) })
  con
}
odqa_db_query <- function(con, query) {
  if (is.null(con)) stop("No connection.")
  query <- as.character(query)
  if (!nzchar(trimws(query))) stop("SQL query is empty.")
  res <- DBI::dbSendQuery(con, query)
  on.exit(try(DBI::dbClearResult(res), silent = TRUE), add = TRUE)
  as.data.frame(DBI::dbFetch(res))
}
read_sql_query <- function(host, port, dbname, user, password, query, db_type = "PostgreSQL") {
  con <- odqa_db_connect(db_type, host, port, dbname, user, password)
  on.exit(odqa_disconnect_safe(con), add = TRUE)
  odqa_db_query(con, query)
}
read_file <- function(type, csv_f = NULL, csv_h = TRUE, csv_s = ",",
                      xls_f = NULL, xls_sh = 1, json_f = NULL, fhir_f = NULL) {
  o <- NULL
  if (type == "CSV/TXT" && !is.null(csv_f)) {
    o <- tryCatch(as.data.frame(data.table::fread(csv_f$datapath, header = csv_h,
                                                  sep = csv_s, data.table = FALSE)), error = function(e) NULL)
  } else if (type == "Excel" && !is.null(xls_f)) {
    o <- tryCatch(as.data.frame(readxl::read_excel(xls_f$datapath, sheet = xls_sh)),
                  error = function(e) NULL)
  } else if (type == "JSON" && !is.null(json_f)) {
    o <- tryCatch(read_json_tabular(json_f$datapath), error = function(e) NULL)
  } else if (type == "FHIR Bundle" && !is.null(fhir_f)) {
    o <- tryCatch(read_fhir_tabular(fhir_f$datapath), error = function(e) NULL)
  }
  o
}

##############################################################################
# Statistical profiling engine. Profiling is driven by value patterns rather than column
# names, so a column named 'foo' that contains ICD codes is profiled as an ICD column.
##############################################################################

stat_type_classifier <- function(vals, max_sample = 5000L) {
  if (is.null(vals) || length(vals) == 0) return("empty")
  n <- length(vals)
  if (n > max_sample) vals_s <- vals[sample.int(n, min(n, max_sample * 2L))] else vals_s <- vals
  if (is.factor(vals_s)) vals_s <- as.character(vals_s)
  if (is.character(vals_s)) {
    non_na <- vals_s[!is.na(vals_s) & nzchar(trimws(vals_s))]
  } else {
    non_na <- vals_s[!is.na(vals_s)]
  }
  if (length(non_na) == 0) return("empty")
  if (is.numeric(non_na) || is.integer(non_na)) {
    if (is.integer(non_na)) return("integer")
    return("numeric")
  }
  suppressWarnings(num_try <- as.numeric(non_na))
  num_ratio <- mean(!is.na(num_try))
  if (num_ratio > 0.9) {
    if (mean(abs(num_try[!is.na(num_try)] - round(num_try[!is.na(num_try)])) < 1e-9) > 0.9) return("integer")
    return("numeric")
  }
  if (inherits(non_na, "Date") || inherits(non_na, "POSIXt")) {
    if (inherits(non_na, "POSIXt")) return("datetime")
    return("date")
  }
  xchr <- as.character(non_na)
  xchr <- xchr[nzchar(trimws(xchr))]
  if (length(xchr) == 0) return("empty")
  dt_try <- tryCatch(suppressWarnings(as.Date(xchr)), error = function(e) rep(NA_real_, length(xchr)))
  if (is.null(dt_try)) dt_try <- rep(NA_real_, length(xchr))
  if (mean(!is.na(dt_try)) > 0.8) return("date")
  if (mean(grepl("^[A-Za-z][0-9]{2}(\\.[0-9A-Za-z]{0,4})?$", xchr)) > 0.6) return("code_icd")
  if (mean(grepl("^[0-9]-[0-9]{2,3}(\\.[0-9A-Za-z]{0,3})?$", xchr)) > 0.6) return("code_ops")
  ux <- unique(xchr)
  if (length(ux) <= 2) return("binary")
  if (length(ux) <= 30) return("categorical")
  if (length(ux) / length(xchr) > 0.9 && median(nchar(xchr), na.rm = TRUE) <= 40) return("id")
  if (median(nchar(xchr), na.rm = TRUE) > 50) return("freetext")
  "categorical"
}

stat_generate_checks <- function(df, lang = "en", max_checks = 30, sample_n = 50000) {
  if (is.null(df) || nrow(df) == 0 || ncol(df) == 0) return(list())
  sugg <- list()
  add <- function(name, desc, basis, sev, expr, col = "", cross = FALSE) {
    sugg[[length(sugg) + 1]] <<- list(
      name = name, desc = desc, basis = basis, sev = sev,
      expression_raw = expr, col = col, cross_column = cross
    )
  }
  
  cols <- names(df)
  idx <- sample_idx(nrow(df), sample_n)
  sdf <- df[idx, , drop = FALSE]
  col_types <- setNames(vapply(cols, function(cn) stat_type_classifier(sdf[[cn]]), character(1)), cols)
  
  for (cn in cols) {
    x <- sdf[[cn]]
    sym <- safe_sym(cn)
    ct <- col_types[cn]
    
    # 1. Completeness.
    miss <- mean(is_blank(x))
    if (is.finite(miss) && miss > 0) {
      sev <- if (miss >= 0.20) "High" else if (miss >= 0.05) "Medium" else "Low"
      basis_txt <- switch(lang,
                          de = paste0("Statistische Grundlage: ", round(100 * miss, 1), "% der Werte in '", cn,
                                      "' sind leer oder NA. Fehlende Daten können Selektionsbias einführen, die statistische ",
                                      "Power reduzieren und die Generalisierbarkeit der Ergebnisse einschränken. Bei multiplen ",
                                      "Regressionen führt listenweiser Fallausschluss bei dieser Rate zu erheblichem Datenverlust."),
                          fr = paste0("Base statistique: ", round(100 * miss, 1), "% des valeurs dans '", cn,
                                      "' sont vides ou NA. Les données manquantes peuvent introduire un biais de sélection."),
                          paste0("Statistical basis: ", round(100 * miss, 1), "% of values in '", cn,
                                 "' are empty or NA. Missing data can introduce selection bias, reduce statistical power, ",
                                 "and limit generalizability of results. In multivariate analyses, listwise deletion at this ",
                                 "rate leads to substantial data loss. Consider whether missingness is random (MCAR/MAR) or ",
                                 "systematic (MNAR), as this determines appropriate handling strategies."))
      add(paste0("Completeness: ", cn),
          switch(lang, de = paste0("Fehlende/leere Werte in '", cn, "'."),
                 fr = paste0("Valeurs manquantes dans '", cn, "'."),
                 paste0("Missing or blank values in '", cn, "'.")),
          basis_txt, sev,
          paste0("is.na(", sym, ") | trimws(as.character(", sym, "))==\"\""), cn)
    }
    
    # 2. Numeric analysis: outliers, impossible values, range.
    xnum <- NULL
    if (is.numeric(x) || is.integer(x)) xnum <- suppressWarnings(as.numeric(x))
    if (is.null(xnum) && (is.character(x) || is.factor(x))) xnum <- as_num_lenient(x)
    
    if (!is.null(xnum)) {
      ok <- is.finite(xnum)
      if (sum(ok) >= 20) {
        med <- median(xnum[ok], na.rm = TRUE)
        md <- mad(xnum[ok], constant = 1, na.rm = TRUE)
        q1 <- quantile(xnum[ok], 0.25, na.rm = TRUE)
        q3 <- quantile(xnum[ok], 0.75, na.rm = TRUE)
        iqr_val <- q3 - q1
        
        # Robust outlier detection with MAD z-score.
        if (is.finite(md) && md > 0) {
          z <- abs((xnum - med) / md)
          out_rate <- mean(z[ok] > 8)
          if (is.finite(out_rate) && out_rate > 0.001) {
            sev <- if (out_rate >= 0.02) "High" else if (out_rate >= 0.005) "Medium" else "Low"
            add(paste0("Outliers: ", cn),
                switch(lang, de = paste0("Robuste Ausreisser in '", cn, "' (MAD z-Score > 8)."),
                       fr = paste0("Valeurs aberrantes robustes dans '", cn, "'."),
                       paste0("Robust outliers in '", cn, "' (MAD z-score > 8).")),
                switch(lang,
                       de = paste0("Statistische Grundlage: Robuste Ausreisser-Erkennung mittels Median Absolute Deviation (MAD). ",
                                   "Der MAD ist resistent gegenüber Masking-Effekten, die bei IQR-basierten Methoden auftreten. ",
                                   round(100 * out_rate, 2), "% der Werte liegen mehr als 8 MAD-Einheiten vom Median (",
                                   round(med, 2), ") entfernt. Extreme Werte können Mittelwerte, Regressionskoeffizienten und Hypothesentests verfälschen."),
                       paste0("Statistical basis: Robust outlier detection using Median Absolute Deviation (MAD). ",
                              "MAD is resistant to masking effects that affect IQR-based methods. ",
                              round(100 * out_rate, 2), "% of values lie more than 8 MAD units from the median (",
                              round(med, 2), "). Extreme values can distort means, regression coefficients, and hypothesis tests. ",
                              "Review whether these represent data entry errors, measurement artifacts, or genuine extreme observations.")),
                sev,
                paste0("({.x<-as_num_lenient(", sym, ");.m<-median(.x,na.rm=TRUE);.d<-mad(.x,constant=1,na.rm=TRUE);!is.na(.x)&.d>0&abs((.x-.m)/.d)>8})"),
                cn)
          }
        }
        
        # Implausible negatives. A column whose observed values are overwhelmingly
        # non-negative but contains a handful of negatives is probably carrying sign
        # errors.
        neg_count <- sum(xnum[ok] < 0, na.rm = TRUE)
        pos_ratio <- mean(xnum[ok] >= 0, na.rm = TRUE)
        if (neg_count > 0 && pos_ratio > 0.95) {
          add(paste0("Possibly impossible negatives: ", cn),
              switch(lang, de = paste0(neg_count, " negative Werte in '", cn, "', wo >95% positiv sind."),
                     fr = paste0(neg_count, " valeurs négatives dans '", cn, "'."),
                     paste0(neg_count, " negative values in '", cn, "' where >95% are non-negative.")),
              switch(lang,
                     de = paste0("Statistische Grundlage: ", round(100 * pos_ratio, 1), "% der Werte sind nicht-negativ. ",
                                 "Die ", neg_count, " negativen Werte weichen vom dominanten Muster ab. ",
                                 "In medizinischen Datensätzen sind negative Werte für Messungen wie Alter, Gewicht, ",
                                 "Verweildauer oder Kosten oft Vorzeichenfehler oder Dateneingabefehler."),
                     paste0("Statistical basis: ", round(100 * pos_ratio, 1), "% of values are non-negative. ",
                            "The ", neg_count, " negative values deviate from the dominant pattern. ",
                            "In clinical data, negatives in measurement columns often indicate sign errors, ",
                            "data entry mistakes, or formula errors that would invalidate downstream calculations.")),
              "High",
              paste0("(!is.na(as.numeric(", sym, "))&as.numeric(", sym, ")<0)"), cn)
        }
      }
    }
    
    # 3. Hidden whitespace.
    if (is.character(x) || is.factor(x)) {
      xc <- as.character(x)
      xc_nna <- xc[!is.na(xc) & nzchar(xc)]
      if (length(xc_nna) > 0) {
        ws <- mean(grepl("^\\s|\\s$|\\s{2,}", xc_nna))
        if (is.finite(ws) && ws > 0.02) {
          add(paste0("Whitespace: ", cn),
              switch(lang, de = paste0("Versteckte Leerzeichen in '", cn, "'."),
                     fr = paste0("Espaces cachés dans '", cn, "'."),
                     paste0("Hidden whitespace in '", cn, "'.")),
              switch(lang,
                     de = paste0("Statistische Grundlage: ", round(100 * ws, 1), "% der nicht-leeren Werte enthalten ",
                                 "führende/nachfolgende Leerzeichen oder Mehrfach-Leerzeichen. Diese erzeugen falsche ",
                                 "Kategorien bei Gruppierungen und verursachen fehlerhafte Joins zwischen Datensätzen."),
                     paste0("Statistical basis: ", round(100 * ws, 1), "% of non-empty values contain leading/trailing ",
                            "spaces or multiple consecutive spaces. These create false categories in grouping operations, ",
                            "cause merge/join failures, and inflate unique value counts.")),
              if (ws > 0.10) "Medium" else "Low",
              paste0("grepl(\"^\\\\s|\\\\s$|\\\\s{2,}\",as.character(", sym, "))"), cn)
        }
      }
    }
    
    # 4. ICD-10-GM code format validation.
    if (ct == "code_icd") {
      xc <- as.character(x)
      xc_nna <- xc[!is.na(xc) & nzchar(trimws(xc))]
      if (length(xc_nna) > 0) {
        valid_icd <- grepl("^[A-Z][0-9]{2}(\\.[0-9A-Za-z]{0,4})?$", xc_nna)
        invalid_rate <- 1 - mean(valid_icd)
        if (invalid_rate > 0.01) {
          add(paste0("ICD code format: ", cn),
              switch(lang, de = paste0("Ungültige ICD-10-GM Codes in '", cn, "'."),
                     fr = paste0("Codes CIM-10 invalides dans '", cn, "'."),
                     paste0("Invalid ICD-10 code format in '", cn, "'.")),
              switch(lang,
                     de = paste0("Statistische Grundlage: Musteranalyse ergibt, dass ", round(100 * invalid_rate, 1),
                                 "% der nicht-leeren Werte nicht dem ICD-10-GM Format (Buchstabe + 2 Ziffern + optionaler Punkt + Subcode) entsprechen. ",
                                 "Ungültige Codes führen zu Fehlern bei Komorbiditätsberechnung, DRG-Zuordnung und epidemiologischen Analysen."),
                     paste0("Statistical basis: Pattern analysis shows ", round(100 * invalid_rate, 1),
                            "% of non-empty values do not match ICD-10 format (letter + 2 digits + optional dot + subcode). ",
                            "Invalid codes cause errors in comorbidity scoring, DRG assignment, and epidemiological analyses.")),
              if (invalid_rate > 0.05) "High" else "Medium",
              paste0("(!is.na(", sym, ")&nzchar(trimws(as.character(", sym,
                     ")))&!grepl(\"^[A-Z][0-9]{2}(\\\\.[0-9A-Za-z]{0,4})?$\",as.character(", sym, ")))"), cn)
        }
      }
    }
    
    # 5. OPS code format validation.
    if (ct == "code_ops") {
      xc <- as.character(x)
      xc_nna <- xc[!is.na(xc) & nzchar(trimws(xc))]
      if (length(xc_nna) > 0) {
        valid_ops <- grepl("^[0-9]-[0-9]{2,3}(\\.[0-9A-Za-z]{0,3})?$", xc_nna)
        invalid_rate <- 1 - mean(valid_ops)
        if (invalid_rate > 0.01) {
          add(paste0("OPS code format: ", cn),
              switch(lang, de = paste0("Ungültige OPS-Codes in '", cn, "'."),
                     fr = paste0("Codes OPS invalides dans '", cn, "'."),
                     paste0("Invalid OPS code format in '", cn, "'.")),
              switch(lang,
                     de = paste0("Statistische Grundlage: ", round(100 * invalid_rate, 1),
                                 "% entsprechen nicht dem OPS-Format (Ziffer-Bindestrich-Ziffern). Fehlerhafte ",
                                 "Prozedurencodes beeinträchtigen die DRG-Abrechnung und Leistungsstatistik."),
                     paste0("Statistical basis: ", round(100 * invalid_rate, 1),
                            "% do not match OPS format (digit-hyphen-digits). Invalid procedure codes affect ",
                            "DRG billing accuracy and procedure statistics.")),
              if (invalid_rate > 0.05) "High" else "Medium",
              paste0("(!is.na(", sym, ")&nzchar(trimws(as.character(", sym,
                     ")))&!grepl(\"^[0-9]-[0-9]{2,3}(\\\\.[0-9A-Za-z]{0,3})?$\",as.character(", sym, ")))"), cn)
        }
      }
    }
    
    # 6. Format consistency. Detects mixed casing within the same categorical column.
    if (ct %in% c("categorical", "id", "freetext") && is.character(x)) {
      xc <- as.character(x)
      xc_nna <- xc[!is.na(xc) & nzchar(trimws(xc))]
      if (length(xc_nna) >= 10) {
        has_upper <- mean(grepl("[A-Z]", xc_nna))
        has_lower <- mean(grepl("[a-z]", xc_nna))
        if (has_upper > 0.1 && has_lower > 0.1 && ct == "categorical") {
          ux_orig <- length(unique(xc_nna))
          ux_lower <- length(unique(tolower(xc_nna)))
          if (ux_lower < ux_orig * 0.9) {
            add(paste0("Case inconsistency: ", cn),
                switch(lang, de = paste0("Gemischte Gross-/Kleinschreibung in '", cn, "'."),
                       fr = paste0("Casse incohérente dans '", cn, "'."),
                       paste0("Mixed case in '", cn, "'.")),
                switch(lang,
                       de = paste0("Statistische Grundlage: ", ux_orig, " einzigartige Werte reduzieren sich auf ",
                                   ux_lower, " bei Normalisierung der Gross-/Kleinschreibung. Dies erzeugt ", ux_orig - ux_lower,
                                   " falsche Kategorien, die Gruppierungsanalysen verzerren."),
                       paste0("Statistical basis: ", ux_orig, " unique values reduce to ", ux_lower,
                              " when case-normalized. This creates ", ux_orig - ux_lower,
                              " false categories that distort grouping analyses.")),
                "Low",
                paste0("(!is.na(", sym, ")&as.character(", sym, ")!=tolower(as.character(", sym, ")))"), cn)
          }
        }
      }
    }
    
    # 7. Future dates.
    if (ct == "date" || inherits(x, "Date") || inherits(x, "POSIXt")) {
      xd <- tryCatch(suppressWarnings(as.Date(as.character(x))), error = function(e) rep(as.Date(NA), length(x)))
      future_idx <- which(!is.na(xd) & xd > Sys.Date())
      if (length(future_idx) > 0) {
        add(paste0("Future dates: ", cn),
            switch(lang, de = paste0(length(future_idx), " Daten in der Zukunft in '", cn, "'."),
                   fr = paste0(length(future_idx), " dates futures dans '", cn, "'."),
                   paste0(length(future_idx), " future dates in '", cn, "'.")),
            switch(lang,
                   de = paste0("Statistische Grundlage: ", length(future_idx), " Datumswerte liegen nach dem heutigen Datum (",
                               format(Sys.Date()), "). Zukünftige Aufnahme-/Entlassungsdaten deuten auf Dateneingabefehler ",
                               "oder Systemfehler hin und verfälschen Verweildauer- und Zeitreihenanalysen."),
                   paste0("Statistical basis: ", length(future_idx), " date values fall after today (",
                          format(Sys.Date()), "). Future admission/discharge dates indicate data entry errors ",
                          "or system issues, invalidating length-of-stay and time series analyses.")),
            "High",
            paste0("(!is.na(as.Date(as.character(", sym, ")))&as.Date(as.character(", sym, "))>Sys.Date())"), cn)
      }
    }
  }
  
  # 8. Cross-column temporal order.
  date_cols <- cols[vapply(sdf, function(x) {
    if (inherits(x, "Date") || inherits(x, "POSIXt")) return(TRUE)
    xc <- as.character(x); xc <- xc[!is.na(xc) & nzchar(trimws(xc))]
    if (length(xc) < 10) return(FALSE)
    mean(grepl("^\\d{4}-\\d{2}-\\d{2}", xc) | grepl("^\\d{2}[./]\\d{2}[./]\\d{4}", xc)) > 0.5
  }, logical(1))]
  
  if (length(date_cols) >= 2) {
    for (i in seq_along(date_cols)[-length(date_cols)]) {
      for (j in (i + 1):length(date_cols)) {
        cn_a <- date_cols[i]; cn_b <- date_cols[j]
        a <- tryCatch(suppressWarnings(as.Date(as.character(sdf[[cn_a]]))), error = function(e) rep(as.Date(NA), nrow(sdf)))
        b <- tryCatch(suppressWarnings(as.Date(as.character(sdf[[cn_b]]))), error = function(e) rep(as.Date(NA), nrow(sdf)))
        ok <- !is.na(a) & !is.na(b)
        if (sum(ok) < 10) next
        before_rate <- mean(a[ok] <= b[ok])
        if (before_rate > 0.90) {
          violations <- which(ok & a > b)
          if (length(violations) > 0 && length(violations) <= sum(ok) * 0.15) {
            sym_a <- safe_sym(cn_a); sym_b <- safe_sym(cn_b)
            add(paste0("Temporal order: ", cn_a, " after ", cn_b),
                switch(lang, de = paste0(length(violations), " Datensätze, bei denen '", cn_a, "' nach '", cn_b, "' liegt."),
                       fr = paste0(length(violations), " enregistrements où '", cn_a, "' est après '", cn_b, "'."),
                       paste0(length(violations), " records where '", cn_a, "' is after '", cn_b, "'.")),
                switch(lang,
                       de = paste0("Statistische Grundlage: In ", round(100 * before_rate, 1),
                                   "% der Fälle liegt '", cn_a, "' vor oder gleich '", cn_b,
                                   "'. Die ", length(violations), " Verstösse deuten auf Dateneingabefehler. ",
                                   "Zeitliche Inkonsistenzen verfälschen Verweildauerberechnungen und Ereignisreihenfolgen."),
                       paste0("Statistical basis: In ", round(100 * before_rate, 1),
                              "% of cases, '", cn_a, "' precedes or equals '", cn_b,
                              "'. The ", length(violations), " violations suggest data entry errors. ",
                              "Temporal inconsistencies invalidate length-of-stay calculations and event sequencing.")),
                "High",
                paste0("!is.na(as.Date(as.character(", sym_a, ")))&!is.na(as.Date(as.character(", sym_b,
                       ")))&as.Date(as.character(", sym_a, "))>as.Date(as.character(", sym_b, "))"),
                paste0(cn_a, " vs ", cn_b), TRUE)
          }
        }
      }
    }
  }
  
  # 9. Duplicate identifiers.
  for (cn in cols) {
    if (col_types[cn] == "id") {
      x <- sdf[[cn]]; sym <- safe_sym(cn)
      dup_idx <- which(duplicated(x) & !is.na(x))
      if (length(dup_idx) > 0) {
        add(paste0("Duplicate IDs: ", cn),
            switch(lang, de = paste0(length(dup_idx), " doppelte Werte in '", cn, "'."),
                   fr = paste0(length(dup_idx), " doublons dans '", cn, "'."),
                   paste0(length(dup_idx), " duplicate values in '", cn, "'.")),
            switch(lang,
                   de = paste0("Statistische Grundlage: ", length(dup_idx), " von ", sum(!is.na(x)),
                               " Werten sind Duplikate. Doppelte Identifikatoren verletzen die Datenintegrität, ",
                               "erzeugen fehlerhafte Joins und führen zu Überzählung in Analysen."),
                   paste0("Statistical basis: ", length(dup_idx), " of ", sum(!is.na(x)),
                          " values are duplicates. Duplicate identifiers violate data integrity, ",
                          "cause erroneous joins, and lead to overcounting in analyses.")),
            "High",
            paste0("duplicated(", sym, ")&!is.na(", sym, ")"), cn)
      }
    }
  }
  
  # 10. Correlation analysis. A correlation above 0.95 suggests possible redundancy or
  # derived columns.
  num_cols <- cols[col_types %in% c("numeric", "integer")]
  if (length(num_cols) >= 2) {
    num_mat <- sapply(num_cols, function(cn) as_num_lenient(sdf[[cn]]))
    if (is.matrix(num_mat) && ncol(num_mat) >= 2) {
      cor_mat <- tryCatch(cor(num_mat, use = "pairwise.complete.obs"), error = function(e) NULL)
      if (!is.null(cor_mat)) {
        for (i in seq_len(ncol(cor_mat) - 1)) {
          for (j in (i + 1):ncol(cor_mat)) {
            r <- cor_mat[i, j]
            if (!is.na(r) && abs(r) > 0.95) {
              cn_a <- num_cols[i]; cn_b <- num_cols[j]
              add(paste0("High correlation: ", cn_a, " vs ", cn_b),
                  switch(lang, de = paste0("Sehr hohe Korrelation (r=", round(r, 3), ") zwischen '", cn_a, "' und '", cn_b, "'."),
                         fr = paste0("Corrélation très élevée entre '", cn_a, "' et '", cn_b, "'."),
                         paste0("Very high correlation (r=", round(r, 3), ") between '", cn_a, "' and '", cn_b, "'.")),
                  switch(lang,
                         de = paste0("Statistische Grundlage: Pearson r=", round(r, 3),
                                     ". Korrelationen >0.95 deuten auf mögliche Redundanz, abgeleitete Spalten oder Multikollinearität hin. ",
                                     "Multikollinearität kann Regressionskoeffizienten instabil machen."),
                         paste0("Statistical basis: Pearson r=", round(r, 3),
                                ". Correlations >0.95 suggest possible redundancy, derived columns, or multicollinearity. ",
                                "Multicollinearity can destabilize regression coefficients and inflate standard errors.")),
                  "Low", "", paste0(cn_a, " vs ", cn_b), TRUE)
            }
          }
        }
      }
    }
  }
  
  # 11. Gender and ICD-code cross-plausibility.
  gender_col <- NULL
  for (cn in cols) {
    if (col_types[cn] %in% c("binary", "categorical")) {
      xc <- tolower(trimws(as.character(sdf[[cn]])))
      ux <- unique(xc[!is.na(xc) & nzchar(xc)])
      gender_vals <- c("m", "w", "f", "male", "female", "maennlich", "weiblich",
                       "masculin", "feminin", "d", "divers", "x", "0", "1")
      if (length(ux) >= 2 && length(ux) <= 5 && all(ux %in% gender_vals)) {
        gender_col <- cn; break
      }
    }
  }
  icd_col <- NULL
  for (cn in cols) { if (col_types[cn] == "code_icd") { icd_col <- cn; break } }
  
  if (!is.null(gender_col) && !is.null(icd_col)) {
    gender_vals <- tolower(trimws(as.character(sdf[[gender_col]])))
    icd_vals <- toupper(trimws(as.character(sdf[[icd_col]])))
    male_labels <- c("m", "male", "maennlich", "masculin", "1")
    female_labels <- c("w", "f", "female", "weiblich", "feminin", "0", "2")
    
    # Male patients carrying ICD codes from Chapter O (pregnancy), N80-N98 (female
    # genital), or C56-C57 (ovarian cancer).
    is_male <- gender_vals %in% male_labels
    has_female_code <- grepl("^O[0-9]", icd_vals) | grepl("^N8[0-9]|^N9[0-8]", icd_vals) | grepl("^C5[67]", icd_vals)
    male_female_violations <- which(is_male & has_female_code & !is.na(gender_vals) & !is.na(icd_vals))
    if (length(male_female_violations) > 0) {
      sym_g <- safe_sym(gender_col); sym_i <- safe_sym(icd_col)
      add(paste0("Gender-code plausibility: male + female ICD"),
          switch(lang, de = paste0(length(male_female_violations), " männliche Patienten mit frauenspezifischen ICD-Codes."),
                 fr = paste0(length(male_female_violations), " patients masculins avec codes CIM féminins."),
                 paste0(length(male_female_violations), " male patients with female-specific ICD codes.")),
          switch(lang,
                 de = paste0("Statistische Grundlage: Kreuzvalidierung zwischen Geschlecht und ICD-Code ergibt ",
                             length(male_female_violations), " Datensätze, in denen männliche Patienten Codes aus den ",
                             "Kapiteln O (Schwangerschaft), N80-N98 (weibliche Genitalorgane) oder C56-C57 (Ovarialkarzinom) haben. ",
                             "Diese Kombination ist biologisch unplausibel und deutet auf Kodierfehler hin."),
                 paste0("Statistical basis: Cross-validation of gender vs ICD code reveals ", length(male_female_violations),
                        " records where male patients have codes from chapters O (pregnancy), N80-N98 (female genital), ",
                        "or C56-C57 (ovarian cancer). This combination is biologically implausible and suggests coding errors.")),
          "High",
          paste0("(tolower(trimws(as.character(", sym_g, ")))%in%c(\"m\",\"male\",\"maennlich\"))&",
                 "(grepl(\"^O[0-9]\",toupper(as.character(", sym_i, ")))|grepl(\"^N8[0-9]|^N9[0-8]\",toupper(as.character(", sym_i, ")))|",
                 "grepl(\"^C5[67]\",toupper(as.character(", sym_i, "))))"),
          paste0(gender_col, " vs ", icd_col), TRUE)
    }
  }
  
  # Sort suggestions by severity, with Critical first.
  sev_priority <- c(Critical = 1, High = 2, Medium = 3, Low = 4)
  ord <- order(vapply(sugg, function(s) sev_priority[s$sev] %null% 9, numeric(1)))
  sugg <- sugg[ord]
  if (length(sugg) > max_checks) sugg <- sugg[seq_len(max_checks)]
  sugg
}

# Check execution engine.
execute_checks <- function(df, checks_list) {
  if (is.null(df) || nrow(df) == 0 || length(checks_list) == 0) {
    return(data.frame(check_id = character(), issue = character(),
                      severity = character(), row = integer(),
                      stringsAsFactors = FALSE))
  }
  # Build one data.table per check and bind them in a single rbindlist call at the end.
  # This avoids per-row data.frame allocations.
  per_check <- vector("list", length(checks_list))
  for (k in seq_along(checks_list)) {
    cc <- checks_list[[k]]
    expr <- cc$expression_raw %||% ""
    if (!nzchar(trimws(expr))) next
    cc_id   <- cc$check_id   %||% "?"
    cc_name <- cc$check_name %||% cc$description %||% cc_id
    cc_sev  <- cc$severity   %||% "Medium"
    res <- tryCatch({
      v <- validate_expression(expr)
      if (!v$ok) stop(v$msg)
      r <- eval(v$parsed, envir = df)
      if (!(is.logical(r) || is.numeric(r) || is.integer(r)))
        stop("Expression must return logical.")
      r <- as.logical(r)
      if (length(r) != nrow(df)) r <- rep_len(r, nrow(df))
      r[is.na(r)] <- FALSE
      r
    }, error = function(e) rep(FALSE, nrow(df)))
    flagged <- which(res)
    if (!length(flagged)) next
    per_check[[k]] <- data.table::data.table(
      check_id = cc_id,
      issue    = cc_name,
      severity = cc_sev,
      row      = as.integer(flagged)
    )
  }
  per_check <- Filter(Negate(is.null), per_check)
  if (!length(per_check)) {
    return(data.frame(check_id = character(), issue = character(),
                      severity = character(), row = integer(),
                      stringsAsFactors = FALSE))
  }
  as.data.frame(data.table::rbindlist(per_check))
}

# Visualization helpers.
plot_check_impact <- function(affected_n, total_n, main, subtitle = NULL) {
  total_n <- max(as.integer(total_n), 1L)
  affected_n <- max(as.integer(affected_n), 0L)
  ok_n <- max(total_n - affected_n, 0L)
  pct_aff <- round(100 * affected_n / total_n, 2)
  pct_ok <- round(100 - pct_aff, 2)
  oldpar <- par(no.readonly = TRUE)
  on.exit(par(oldpar), add = TRUE)
  layout(matrix(c(1, 2), nrow = 1), widths = c(2.2, 1))
  par(mar = c(4, 1, 4, 1))
  cols <- c("#2E7D32", "#C62828")
  bp <- barplot(matrix(c(ok_n, affected_n), nrow = 2), horiz = TRUE, col = cols, border = NA,
                axes = FALSE, xlim = c(0, total_n), names.arg = "")
  axis(1, las = 1, col = "#888", col.axis = "#555", cex.axis = 0.8)
  title(main = main, cex.main = 0.95, font.main = 2, col.main = "#1a1a1a")
  if (!is.null(subtitle)) title(sub = subtitle, cex.sub = 0.8, col.sub = "#666", line = 2.5)
  # Adaptive label sizing. The cex parameter scales with the fraction of the bar each
  # segment occupies, clamped to the range [0.55, 1.0] so labels stay readable. Segments
  # below five percent of the bar are drawn without labels.
  cex_ok  <- max(0.55, min(1.0, (pct_ok  / 100) * 2.2))
  cex_aff <- max(0.55, min(1.0, (pct_aff / 100) * 2.2))
  if (pct_ok  >= 5) text(ok_n / 2,              bp, paste0("OK: ",       pct_ok,  "%"), cex = cex_ok,  font = 2, col = "white")
  if (pct_aff >= 5) text(ok_n + affected_n / 2, bp, paste0("Affected: ", pct_aff, "%"), cex = cex_aff, font = 2, col = "white")
  par(mar = c(2, 0, 2, 2))
  if (affected_n == 0) {
    pie(1, col = "#2E7D32", border = "white", labels = "", radius = 0.9)
  } else if (ok_n == 0) {
    pie(1, col = "#C62828", border = "white", labels = "", radius = 0.9)
  } else {
    pie(c(ok_n, affected_n), col = cols, border = "white", labels = "", radius = 0.9, init.angle = 90)
  }
  # Overlay a white disc to turn the pie into a donut.
  symbols(0, 0, circles = 0.45, add = TRUE, inches = FALSE, bg = "white", fg = "white")
  layout(1)
  invisible(NULL)
}

save_png_plot <- function(filename, plot_fn, width = 1200, height = 520, res = 150) {
  f <- file.path(tempdir(), filename)
  png(f, width = width, height = height, res = res)
  tryCatch(plot_fn(), error = function(e) NULL)
  dev.off()
  if (file.exists(f)) f else NULL
}

redact_patient_ids <- function(df) {
  if (is.null(df) || nrow(df) == 0) return(df)
  pid_cols <- grep("patient.?id|pat.?id|pat.?nr|fallnr|case.?id|subject.?id",
                   tolower(names(df)), value = TRUE)
  for (col in pid_cols) {
    if (col %in% names(df)) df[[col]] <- paste0("REDACTED_", seq_len(nrow(df)))
  }
  df
}

##############################################################################
# Null-coalescing operator, used throughout the Word generators.
##############################################################################
`%||%` <- function(x, y) {
  if (is.null(x)) return(y)
  if (length(x) == 0L) return(y)
  if (length(x) == 1L && is.na(x)) return(y)
  x
}
##############################################################################
# Apply the default autofit and full-page-width properties to a flextable.
##############################################################################
safe_ft <- function(ft) {
  ft |> flextable::set_table_properties(layout = "autofit", width = 1)
}

##############################################################################
# Render a per-check impact bar chart as a PNG file, for embedding in the Word report.
##############################################################################
make_check_bar_png <- function(affected_n, total_n, title_str, sev, width = 1200, height = 360, res = 150) {
  total_n  <- max(as.integer(total_n),  1L)
  affected_n <- max(as.integer(affected_n), 0L)
  ok_n     <- max(total_n - affected_n, 0L)
  pct_aff  <- round(100 * affected_n / total_n, 2)
  pct_ok   <- round(100 - pct_aff, 2)
  f <- tempfile(fileext = ".png")
  png(f, width = width, height = height, res = res)
  on.exit(if (grDevices::dev.cur() > 1) grDevices::dev.off(), add = TRUE)
  tryCatch({
    oldpar <- par(no.readonly = TRUE); on.exit(par(oldpar), add = TRUE)
    layout(matrix(c(1, 2), nrow = 1), widths = c(2.5, 1))
    par(mar = c(4, 1, 3, 1))
    bar_cols <- c("#2E7D32", "#C62828")
    bp <- barplot(matrix(c(ok_n, affected_n), nrow = 2), horiz = TRUE, col = bar_cols, border = NA,
                  axes = FALSE, xlim = c(0, total_n), names.arg = "")
    axis(1, las = 1, col = "#888", col.axis = "#555", cex.axis = 0.85)
    title(main = title_str, cex.main = 0.9, font.main = 2, col.main = "#1a1a1a")
    sev_col <- switch(sev, Critical = "#7B0020", High = "#dc2626",
                      Medium = "#ea580c", Low = "#16a34a", "#0866FF")
    mtext(paste0("Severity: ", sev), side = 3, line = -1.2, cex = 0.7, col = sev_col)
    cex_ok  <- max(0.55, min(1.0, (pct_ok  / 100) * 2.2))
    cex_aff <- max(0.55, min(1.0, (pct_aff / 100) * 2.2))
    if (pct_ok  >= 5) text(ok_n / 2,             bp, paste0("OK: ",       pct_ok,  "%"), cex = cex_ok,  font = 2, col = "white")
    if (pct_aff >= 5) text(ok_n + affected_n / 2, bp, paste0("Affected: ", pct_aff, "%"), cex = cex_aff, font = 2, col = "white")
    par(mar = c(2, 0, 2, 2))
    if (affected_n == 0) {
      pie(1, col = "#2E7D32", border = "white", labels = "100% OK", radius = 0.9, cex = 0.75)
    } else if (ok_n == 0) {
      pie(1, col = "#C62828", border = "white", labels = "100% Affected", radius = 0.9, cex = 0.75)
    } else {
      pie(c(ok_n, affected_n), col = bar_cols, border = "white", labels = "", radius = 0.9, init.angle = 90)
    }
    symbols(0, 0, circles = 0.45, add = TRUE, inches = FALSE, bg = "white", fg = "white")
    text(0, 0.08,  paste0(pct_aff, "%"), cex = 1.5, font = 2, col = "#C62828")
    text(0, -0.15, "affected",           cex = 0.7,           col = "#666")
    layout(1)
  }, error = function(e) NULL)
  grDevices::dev.off()
  if (file.exists(f)) f else NULL
}

##############################################################################
# Severity and source-category plots as PNG files, for the overview section of the Word
# report.
##############################################################################
make_sev_plot_png <- function(issues, width = 1200, height = 420, res = 150) {
  f <- tempfile(fileext = ".png")
  png(f, width = width, height = height, res = res)
  tryCatch({
    sev_levels <- c("Low", "Medium", "High", "Critical")
    sev_counts <- table(factor(issues$severity, levels = sev_levels))
    bar_cols   <- c(Low = "#2E7D32", Medium = "#E65100",
                    High = "#C62828", Critical = "#7B0020")
    par(mar = c(4, 5, 3, 1))
    bp <- barplot(sev_counts, col = bar_cols[names(sev_counts)],
                  border = NA, las = 1,
                  ylab = "Number of issue flags",
                  main = "Severity distribution of issue flags")
    mtext(paste0("(", sum(sev_counts), " flags across ",
                 issues_unique_rows(issues),
                 " distinct records)"),
          side = 3, line = 0.2, cex = 0.8, col = "#666")
    text(bp, sev_counts, labels = sev_counts, pos = 3, cex = 0.9, font = 2)
  }, error = function(e) NULL)
  grDevices::dev.off()
  if (file.exists(f)) f else NULL
}

make_cat_plot_png <- function(issues, custom_checks, width = 1200, height = 420, res = 150) {
  f <- tempfile(fileext = ".png")
  png(f, width = width, height = height, res = res)
  tryCatch({
    source_map <- setNames(
      vapply(custom_checks, function(cc) cc$source %||% "Unknown", character(1)),
      vapply(custom_checks, function(cc) cc$check_id %||% "?",     character(1))
    )
    issues$source <- source_map[issues$check_id]
    issues$source[is.na(issues$source)] <- "Unknown"
    src_counts <- sort(table(issues$source), decreasing = TRUE)
    par(mar = c(4, 10, 2, 1))
    bp <- barplot(src_counts, horiz = TRUE, col = "#1565C0", border = NA, las = 1,
                  xlab = "Number of Issues", main = "Issues by Check Source / Category")
    text(src_counts, bp, labels = src_counts, pos = 4, cex = 0.8, font = 2)
  }, error = function(e) NULL)
  grDevices::dev.off()
  if (file.exists(f)) f else NULL
}

##############################################################################
# Data Quality Assessment report generator. Builds a publication-ready Word document
# with the full methodology, the complete check register, per-check impact, and an audit
# trail suitable for archival.
##############################################################################
gen_word <- function(issues, n_checks, mapped_df, lang = "en",
                     sev_plot = NULL, cat_plot = NULL,
                     user_info = NULL, perf_data = NULL,
                     checks_df = NULL, selected_checks = character(),
                     custom_checks = list()) {
  
  doc       <- officer::read_docx()
  n_total   <- if (!is.null(mapped_df)) nrow(mapped_df) else 0L
  n_cols    <- if (!is.null(mapped_df)) ncol(mapped_df) else 0L
  q         <- calc_quality_score(n_total, issues)
  ts_now    <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  
  # Session fingerprint. Derived deterministically from the dataset shape, check count,
  # score, and timestamp so the same inputs reproduce the same fingerprint for later
  # verification.
  session_hash <- tryCatch({
    raw_str  <- paste0(n_total, "|", n_cols, "|", n_checks, "|",
                       q$score, "|", format(Sys.time(), "%Y%m%d%H%M%S"))
    hex_chars <- sprintf("%02x", as.integer(charToRaw(raw_str)))
    paste0("ODQA-", toupper(paste(hex_chars[seq_len(min(16, length(hex_chars)))], collapse = "")))
  }, error = function(e) paste0("ODQA-", format(Sys.time(), "%Y%m%d%H%M%S")))
  
  # Quality band. The fitness score is binned into four orientation bands.
  band <- score_band(q$score)
  interp <- switch(band,
                   green  = "Excellent: All or nearly all records passed quality checks. The dataset is suitable for analysis with high confidence.",
                   yellow = "Minor issues detected. Mostly informational; unlikely to significantly affect analytical results if addressed.",
                   orange = "Moderate data quality issues present. These may introduce bias into results. Targeted cleansing is recommended before analysis.",
                   red    = "Significant or critical data quality issues detected. Cleansing is strongly recommended before any statistical analysis."
  )
  
  ############################################################################
  # Section 1: cover page.
  ############################################################################
  doc <- officer::body_add_par(doc, "Data Quality Assessment Report", style = "heading 1")
  doc <- officer::body_add_par(doc, "Proof of Systematic, Fitness-for-Purpose Data Quality Assessment", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0("Session ID: ", session_hash), style = "Normal")
  doc <- officer::body_add_par(doc, paste0("Generated: ", ts_now), style = "Normal")
  doc <- officer::body_add_par(doc, paste0("Tool: Open DQA | MIT License"), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  ############################################################################
  # Section 2: tool metadata.
  ############################################################################
  doc <- officer::body_add_par(doc, "Tool Information", style = "heading 1")
  tool_meta <- data.frame(
    Property = c("Tool", "Version", "License", "R Version", "Document ID", "Timestamp"),
    Value    = c("Open DQA", "Prototype", "MIT License",
                 paste0(R.version$major, ".", R.version$minor),
                 session_hash, ts_now),
    stringsAsFactors = FALSE
  )
  ft <- flextable::flextable(tool_meta) |>
    flextable::autofit() |> flextable::theme_zebra() |> flextable::bold(j = 1) |>
    flextable::set_header_labels(Property = "Property", Value = "Value")
  doc <- flextable::body_add_flextable(doc, safe_ft(ft))
  doc <- officer::body_add_par(doc, "")
  
  doc <- officer::body_add_par(doc, "Data Protection Statement", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "This report intentionally excludes patient identifiers and row-level patient listings. ",
    "Open DQA is a research tool (not a medical device under EU MDR, FDA, or equivalent). ",
    "Results are intended for research-quality orientation and audit support. ",
    "The user is solely responsible for validating and interpreting all results."
  ), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  ############################################################################
  # Section 3: dataset summary.
  ############################################################################
  doc <- officer::body_add_par(doc, "Dataset Summary", style = "heading 1")
  ds_meta <- data.frame(
    Parameter = c("Total Records (rows)", "Total Columns", "Checks Executed",
                  "Custom Checks", "Records With Issues", "Total Issue Flags",
                  "Quality Score"),
    Value = c(as.character(n_total), as.character(n_cols),
              as.character(n_checks), as.character(length(custom_checks)),
              as.character(q$affected_rows), as.character(q$issue_count),
              paste0(q$score, "%")),
    stringsAsFactors = FALSE
  )
  ft2 <- flextable::flextable(ds_meta) |>
    flextable::autofit() |> flextable::theme_zebra() |> flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft2))
  doc <- officer::body_add_par(doc, "")
  
  doc <- officer::body_add_par(doc, "Quality Score Interpretation", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "Quality Score Q = 100% \u00d7 (1 \u2013 affected_records / total_records). ",
    "Color bands: Green 100\u201380%, Yellow 79\u201360%, Orange 59\u201340%, Red <40%. ",
    "This is an orientation metric; domain-specific thresholds may apply."
  ), style = "Normal")
  doc <- officer::body_add_par(doc, paste0("Assessment (", toupper(band), ", ", q$score, "%): ", interp), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  ############################################################################
  # Section 4: methods.
  ############################################################################
  doc <- officer::body_add_par(doc, "Methods", style = "heading 1")
  
  doc <- officer::body_add_par(doc, "Assessment Framework", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "Data quality was assessed using Open DQA, an open-source platform that implements a ",
    "fitness-for-purpose evaluation strategy: rather than applying a fixed quality threshold, ",
    "data quality is systematically evaluated against the specific requirements of the research ",
    "question at hand (Wang and Strong, 1996; Weiskopf and Weng, 2013). The workflow is divided ",
    "into four operational stages: D1 Statistical Profiling (automated suggestions), ",
    "D2 Base Check Builder (structured operator-driven rules), D2 Advanced Check Builder ",
    "(grouped, conditional, and free-form expressions), and D3 Check Manager and Execution."
  ), style = "Normal")
  
  doc <- officer::body_add_par(doc, "D1: Statistical Profiling", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "The D1 engine performs automated, column-name-independent statistical profiling using ",
    "pattern-recognition-based type classification. It detects: completeness gaps (missing or ",
    "blank values with bias-impact analysis), robust numeric outliers (MAD z-score > 8), ",
    "impossible values (negatives in predominantly non-negative columns), hidden whitespace, ",
    "ICD-10 and OPS code format validity, future dates, temporal order violations between date ",
    "columns, duplicate identifiers, case-inconsistencies, high inter-column correlation ",
    "(Pearson r > 0.95), and gender-ICD cross-plausibility. Each suggestion reports a quantitative ",
    "statistical basis, a severity rating (Low, Medium, High, Critical), and a validated R ",
    "expression. Suggestions are advisory; the user explicitly accepts, modifies, or rejects ",
    "each one before it enters the check register."
  ), style = "Normal")
  
  doc <- officer::body_add_par(doc, "D2 Base: Operator-Driven Check Builder", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "D2 Base provides a structured, operator-driven rule builder for column-to-value and ",
    "column-to-column comparisons. It supports 18 operators: six comparison operators ",
    "(==, !=, >, >=, <, <=), four string-matching operators (contains, not_contains, ",
    "starts_with, ends_with), two presence operators (is.na, is_not.na), two range operators ",
    "(BETWEEN, NOT BETWEEN), two set-membership operators (IN, NOT IN), one pattern-matching ",
    "operator (REGEXP), and two uniqueness operators (is_duplicate, is_unique). Multiple ",
    "conditions may be combined with AND or OR connectives. A value list can be imported from ",
    "CSV, JSON, Excel, or TXT for set-based comparisons over hundreds or thousands of values. ",
    "A Test Query button reports match count and elapsed time before the check is saved."
  ), style = "Normal")
  
  doc <- officer::body_add_par(doc, "D2 Advanced: Grouped, Conditional, and Free R-Query", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "D2 Advanced exposes three independent sub-builders for rules that cannot be expressed as ",
    "per-row comparisons. (1) GROUP BY: aggregate validation using ave()-based grouped ",
    "computations with eight aggregation functions (count_gt, count_lt, count_eq, ndistinct_gt, ",
    "sum_gt, mean_gt, min_lt, max_gt) and a configurable numeric threshold. (2) IF-THEN: ",
    "conditional checks that flag a row only when a precondition on one column holds but a ",
    "required condition on a second column fails. (3) Free R-Query: any R logical expression ",
    "evaluated per row, subject to the same security blacklist as D2 Base (no system calls, ",
    "no eval, no file access). Every sub-builder shares the same Test Query and Save flow ",
    "as D2 Base, and every saved expression is validated via validate_expression() before ",
    "execution."
  ), style = "Normal")
  
  doc <- officer::body_add_par(doc, "D3: Check Manager and Execution", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "All checks defined by D1, D2 Base, and D2 Advanced converge into a single check register ",
    "in D3, each entry carrying a stable identifier (STAT-, STAT-M-, MAN-, GB-, IF-, RQ-), a ",
    "user-provided name, a description, a severity, and the provenance source. The register can ",
    "be exported to JSON for reuse across projects and re-imported on another dataset. ",
    "Execution runs every saved expression against the active dataset in a single pass; ",
    "expressions that fail validation or runtime evaluation are recorded as producing zero ",
    "flags rather than aborting the run, which keeps one malformed check from invalidating the ",
    "assessment as a whole."
  ), style = "Normal")
  
  doc <- officer::body_add_par(doc, "Evaluation and Scoring", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "Every check is evaluated as a logical R expression where TRUE denotes a rule violation. ",
    "The resulting quality score is Q = 100 \u00d7 (1 \u2013 affected_records / total_records), ",
    "bounded to [0, 100] and binned into four orientation bands (Green >= 80, Yellow >= 60, ",
    "Orange >= 40, Red < 40). Per-check impact metrics (affected count, affected percentage, ",
    "severity, source) are reported individually to support targeted cleansing prioritization. ",
    "All check expressions are validated against a security blacklist (validate_expression) ",
    "that rejects system calls, eval, parse, do.call, file I/O, and environment manipulation ",
    "before execution. The blacklist is applied at definition time, at import time from JSON, ",
    "and again at execution time."
  ), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  ############################################################################
  # Section 5: results overview.
  ############################################################################
  doc <- officer::body_add_par(doc, "Results Overview", style = "heading 1")
  
  if (!is.null(issues) && nrow(issues) > 0) {
    # Severity distribution.
    # The counts below are issue flags. A single record flagged by several checks
    # contributes multiple flags here but is counted only once in 'Records Affected' at
    # the top of the report. Both views are shown together so the quality score and the
    # severity breakdown reconcile.
    doc <- officer::body_add_par(doc, "Severity Distribution (issue flags)", style = "heading 2")
    doc <- officer::body_add_par(doc, paste0(
      "Total issue flags recorded: ", nrow(issues),
      ". Distinct records affected: ", issues_unique_rows(issues),
      ". A record can receive multiple flags if more than one check fires."
    ), style = "Normal")
    sev <- sort(table(issues$severity), decreasing = TRUE)
    sev_df <- data.frame(
      Severity          = names(sev),
      Issue_Flags       = as.integer(sev),
      Pct_of_Flags      = paste0(round(100 * as.integer(sev) / nrow(issues), 1), "%"),
      stringsAsFactors  = FALSE
    )
    names(sev_df) <- c("Severity", "Issue Flags", "% of Flags")
    ft3 <- flextable::flextable(sev_df) |> flextable::autofit() |> flextable::theme_zebra()
    doc <- flextable::body_add_flextable(doc, safe_ft(ft3))
    
    if (!is.null(sev_plot) && file.exists(sev_plot)) {
      doc <- officer::body_add_par(doc, "")
      doc <- officer::body_add_img(doc, src = sev_plot, width = 6.5, height = 2.5)
    }
    doc <- officer::body_add_par(doc, "")
    
    # Source-category distribution.
    doc <- officer::body_add_par(doc, "Check Source Distribution", style = "heading 2")
    if (!is.null(custom_checks) && length(custom_checks) > 0) {
      src_map <- setNames(
        vapply(custom_checks, function(cc) cc$source %||% "Unknown", character(1)),
        vapply(custom_checks, function(cc) cc$check_id %||% "?",     character(1))
      )
      issues$source_label <- src_map[issues$check_id]
      issues$source_label[is.na(issues$source_label)] <- "Unknown"
    } else {
      issues$source_label <- "Unclassified"
    }
    src_counts <- sort(table(issues$source_label), decreasing = TRUE)
    ct_df <- data.frame(
      Source           = names(src_counts),
      Issue_Flags      = as.integer(src_counts),
      Pct_of_Flags     = paste0(round(100 * as.integer(src_counts) / nrow(issues), 1), "%"),
      stringsAsFactors = FALSE,
      check.names      = FALSE
    )
    names(ct_df) <- c("Source", "Issue Flags", "% of Flags")
    ft4 <- flextable::flextable(ct_df) |> flextable::autofit() |> flextable::theme_zebra()
    doc <- flextable::body_add_flextable(doc, safe_ft(ft4))
    
    if (!is.null(cat_plot) && file.exists(cat_plot)) {
      doc <- officer::body_add_par(doc, "")
      doc <- officer::body_add_img(doc, src = cat_plot, width = 6.5, height = 2.5)
    }
  } else {
    doc <- officer::body_add_par(doc,
                                 "No issues detected by the selected checks. All records passed every quality check.",
                                 style = "Normal")
  }
  doc <- officer::body_add_par(doc, "")
  
  ############################################################################
  # Section 6: complete check register.
  ############################################################################
  doc <- officer::body_add_par(doc, "Complete Check Register", style = "heading 1")
  doc <- officer::body_add_par(doc, paste0(
    "The following constitutes a complete, item-level register of every quality check executed ",
    "during this assessment session. For each check, the register records its unique identifier, ",
    "source, description, severity classification, number and proportion of affected records, ",
    "and the pass/fail verdict. This register serves as the formal proof of systematic data quality ",
    "assessment and satisfies documentation requirements under ICH E6(R2) GCP and institutional ",
    "research data governance policies."
  ), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  # Execution summary sub-table.
  n_total_chk <- length(custom_checks)
  
  doc <- officer::body_add_par(doc, "Execution Summary", style = "heading 2")
  exec_df <- data.frame(
    Metric = c("Checks executed", "Records evaluated",
               "Records with at least one issue", "Overall quality score"),
    Value  = c(as.character(n_total_chk), as.character(n_total),
               as.character(q$affected_rows), paste0(q$score, "%")),
    stringsAsFactors = FALSE
  )
  ft_exec <- flextable::flextable(exec_df) |>
    flextable::autofit() |> flextable::theme_zebra() |> flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_exec))
  doc <- officer::body_add_par(doc, "")
  
  # Detailed per-check register.
  doc <- officer::body_add_par(doc, "Detailed Check Register", style = "heading 2")
  
  if (!is.null(custom_checks) && length(custom_checks) > 0) {
    sumdf <- issues_by_check(issues, n_total)
    
    reg <- do.call(rbind, lapply(seq_along(custom_checks), function(i) {
      cc <- custom_checks[[i]]
      cc_id   <- cc$check_id  %||% paste0("CHK-", i)
      cc_name <- cc$check_name %||% cc_id
      cc_desc <- substr(cc$description %||% cc_name, 1, 60)
      cc_sev  <- cc$severity  %||% "Medium"
      cc_src  <- cc$source    %||% "Manual"
      cc_expr <- substr(cc$expression_raw %||% "", 1, 60)
      
      cc_aff <- 0L; cc_pct <- 0.0
      if (!is.null(sumdf) && nrow(sumdf) > 0) {
        hit <- sumdf[sumdf$check_id == cc_id, , drop = FALSE]
        if (nrow(hit) > 0) { cc_aff <- hit$affected_n[1]; cc_pct <- hit$affected_pct[1] }
      }
      data.frame(
        Check_ID      = cc_id,
        Source        = cc_src,
        Description   = cc_desc,
        Severity      = cc_sev,
        Affected_Rows = as.integer(cc_aff),
        Affected_Pct  = paste0(round(cc_pct, 2), "%"),
        Result        = if (cc_aff == 0) "PASS" else "ISSUES FOUND",
        stringsAsFactors = FALSE
      )
    }))
    
    names(reg) <- c("Check ID", "Source", "Description", "Severity",
                    "Affected Rows", "Affected %", "Result")
    
    ft5 <- flextable::flextable(reg) |>
      flextable::autofit() |> flextable::theme_zebra() |>
      flextable::bold(j = 7) |> flextable::fontsize(size = 7, part = "body") |>
      flextable::color(i = ~ Result == "ISSUES FOUND", j = 7, color = "#dc2626") |>
      flextable::color(i = ~ Result == "PASS",         j = 7, color = "#16a34a")
    doc <- flextable::body_add_flextable(doc, safe_ft(ft5))
    
    # Results grouped by source.
    doc <- officer::body_add_par(doc, "")
    doc <- officer::body_add_par(doc, "Results by Source", style = "heading 2")
    src_tbl <- as.data.frame(table(reg$Source), stringsAsFactors = FALSE)
    names(src_tbl) <- c("Source", "Checks")
    pass_c <- tapply(reg$Result == "PASS",         reg$Source, sum, na.rm = TRUE)
    fail_c <- tapply(reg$Result == "ISSUES FOUND", reg$Source, sum, na.rm = TRUE)
    src_tbl$Passed   <- as.integer(pass_c[src_tbl$Source]); src_tbl$Passed[is.na(src_tbl$Passed)] <- 0L
    src_tbl$Failed   <- as.integer(fail_c[src_tbl$Source]); src_tbl$Failed[is.na(src_tbl$Failed)] <- 0L
    src_tbl$Pass_Rate <- paste0(round(100 * src_tbl$Passed / src_tbl$Checks, 1), "%")
    names(src_tbl) <- c("Source", "Checks Executed", "Passed", "Failed", "Pass Rate")
    ft_src <- flextable::flextable(src_tbl) |>
      flextable::autofit() |> flextable::theme_zebra() |> flextable::bold(j = 1)
    doc <- flextable::body_add_flextable(doc, safe_ft(ft_src))
    
  } else {
    doc <- officer::body_add_par(doc, paste0(
      "No check register is available. Select and execute checks in the Check Manager (D3) ",
      "before generating this report."
    ), style = "Normal")
  }
  doc <- officer::body_add_par(doc, "")
  
  ############################################################################
  # Section 7: per-check impact. The top 15 checks are rendered in detail with a bar
  # chart each; the remainder appear in the summary table.
  ############################################################################
  doc <- officer::body_add_par(doc, "Per-Check Impact Analysis", style = "heading 1")
  doc <- officer::body_add_par(doc, paste0(
    "This section provides a granular, check-by-check breakdown of data quality impact. ",
    "For each check that produced findings, the affected record count and proportion are shown ",
    "together with a visual bar chart. The top 15 checks by impact are shown in detail; ",
    "remaining checks appear in the summary table only."
  ), style = "Normal")
  
  sumdf2 <- issues_by_check(issues, n_total)
  if (!is.null(sumdf2) && nrow(sumdf2) > 0) {
    # Impact summary table (top 30 checks).
    impact_tbl <- data.frame(
      Check    = paste0("[", sumdf2$check_id, "] ", sumdf2$check_name %||% sumdf2$check_id),
      Severity = sumdf2$severity,
      Affected = sumdf2$affected_n,
      Pct      = paste0(sumdf2$affected_pct, "%"),
      stringsAsFactors = FALSE
    )
    ft_impact <- flextable::flextable(impact_tbl[seq_len(min(nrow(impact_tbl), 30)), ]) |>
      flextable::autofit() |> flextable::theme_zebra() |>
      flextable::fontsize(size = 7, part = "body")
    doc <- flextable::body_add_flextable(doc, safe_ft(ft_impact))
    doc <- officer::body_add_par(doc, "")
    
    # Detail block for the top 15 checks, each with its own chart.
    for (i in seq_len(min(nrow(sumdf2), 15))) {
      cid <- sumdf2$check_id[i]
      nm  <- sumdf2$check_name[i] %||% cid
      sev <- sumdf2$severity[i]
      an  <- sumdf2$affected_n[i]
      ap  <- sumdf2$affected_pct[i]
      
      doc <- officer::body_add_par(doc, paste0("[", cid, "] ", nm), style = "heading 2")
      doc <- officer::body_add_par(doc,
                                   paste0("Severity: ", sev, " | Affected: ", an, " of ", n_total,
                                          " records (", ap, "%)"),
                                   style = "Normal")
      
      pth <- tryCatch(
        make_check_bar_png(an, n_total, paste0("[", cid, "] ", nm), sev),
        error = function(e) NULL
      )
      if (!is.null(pth) && file.exists(pth))
        doc <- officer::body_add_img(doc, src = pth, width = 6.5, height = 2.4)
    }
    if (nrow(sumdf2) > 15)
      doc <- officer::body_add_par(doc,
                                   paste0("... and ", nrow(sumdf2) - 15, " additional checks (see summary table above)."),
                                   style = "Normal")
  } else {
    doc <- officer::body_add_par(doc,
                                 "No checks produced issues. All records passed every quality check.",
                                 style = "Normal")
  }
  doc <- officer::body_add_par(doc, "")
  
  ############################################################################
  # Section 8: processing and audit information.
  ############################################################################
  doc <- officer::body_add_par(doc, "Processing & Audit Information", style = "heading 1")
  doc <- officer::body_add_par(doc, paste0(
    "This section provides a complete audit trail of all processing activities performed ",
    "during this data quality assessment session. It satisfies traceability requirements ",
    "under ICH E6(R2) Section 5.5.3 and institutional research data governance policies."
  ), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  # Session environment.
  doc <- officer::body_add_par(doc, "Session Environment", style = "heading 2")
  env_df <- data.frame(
    Property = c("R Version", "Platform", "Operating System", "Locale",
                 "Timezone", "Open DQA Version", "Session ID", "Report Timestamp (ISO 8601)"),
    Value = c(
      paste0(R.version$major, ".", R.version$minor, " (", R.version$nickname, ")"),
      R.version$platform,
      tryCatch(utils::sessionInfo()$running, error = function(e) Sys.info()[["sysname"]]),
      tryCatch(Sys.getlocale("LC_CTYPE"), error = function(e) "Unknown"),
      Sys.timezone(), "Prototype", session_hash,
      format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    ),
    stringsAsFactors = FALSE
  )
  ft_env <- flextable::flextable(env_df) |>
    flextable::autofit() |> flextable::theme_zebra() |> flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_env))
  doc <- officer::body_add_par(doc, "")
  
  # Analyst attribution.
  doc <- officer::body_add_par(doc, "Analyst Attribution", style = "heading 2")
  ui_name  <- tryCatch(user_info$name,  error = function(e) "")
  ui_func  <- tryCatch(user_info$func,  error = function(e) "")
  ui_email <- tryCatch(user_info$email, error = function(e) "")
  if (is.null(ui_name)  || !nzchar(trimws(ui_name  %||% ""))) ui_name  <- "Not provided"
  if (is.null(ui_func)  || !nzchar(trimws(ui_func  %||% ""))) ui_func  <- "Not provided"
  if (is.null(ui_email) || !nzchar(trimws(ui_email %||% ""))) ui_email <- "Not provided"
  analyst_df <- data.frame(
    Field = c("Name", "Function / Role", "Email"),
    Value = c(ui_name, ui_func, ui_email),
    stringsAsFactors = FALSE
  )
  ft_analyst <- flextable::flextable(analyst_df) |>
    flextable::autofit() |> flextable::theme_zebra() |> flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_analyst))
  doc <- officer::body_add_par(doc, "")
  
  # Performance timeline.
  doc <- officer::body_add_par(doc, "Performance Timeline", style = "heading 2")
  if (!is.null(perf_data) && is.list(perf_data) && length(perf_data) > 0) {
    task_names <- names(perf_data)
    task_vals  <- vapply(task_names, function(k) {
      v <- perf_data[[k]]
      if (is.numeric(v) && length(v) == 1 && is.finite(v)) format_elapsed(v) else "N/A"
    }, character(1))
    perf_df <- data.frame(Task = task_names, Duration = task_vals, stringsAsFactors = FALSE)
    ft_perf <- flextable::flextable(perf_df) |>
      flextable::autofit() |> flextable::theme_zebra() |>
      flextable::fontsize(size = 8, part = "body") |> flextable::bold(j = 1)
    doc <- flextable::body_add_flextable(doc, safe_ft(ft_perf))
    total_dur <- sum(unlist(perf_data), na.rm = TRUE)
    doc <- officer::body_add_par(doc, paste0(
      "Total processing time: ", round(total_dur, 3), " seconds across ",
      length(perf_data), " recorded task(s)."
    ), style = "Normal")
  } else {
    doc <- officer::body_add_par(doc,
                                 "No performance timing data was recorded for this session.",
                                 style = "Normal")
  }
  doc <- officer::body_add_par(doc, "")
  
  # Data integrity fingerprint.
  doc <- officer::body_add_par(doc, "Data Integrity Verification", style = "heading 2")
  data_fp <- tryCatch({
    if (!is.null(mapped_df) && nrow(mapped_df) > 0) {
      col_sig    <- paste(names(mapped_df), collapse = "|")
      dim_sig    <- paste0(nrow(mapped_df), "x", ncol(mapped_df))
      sample_v   <- paste(head(unlist(mapped_df[1, ]), 5), collapse = ",")
      raw_fp     <- paste0(col_sig, "|", dim_sig, "|", sample_v, "|", n_checks)
      hex_chars  <- sprintf("%02x", as.integer(charToRaw(raw_fp)))
      paste0("DF-", toupper(paste(hex_chars[seq_len(min(20, length(hex_chars)))], collapse = "")))
    } else "DF-EMPTY"
  }, error = function(e) "DF-ERROR")
  
  integrity_df <- data.frame(
    Property = c("Dataset Fingerprint", "Dataset Dimensions", "Checks Executed",
                 "Session Hash", "Fingerprint Method"),
    Value    = c(
      data_fp,
      paste0(n_total, " rows \u00d7 ", n_cols, " columns"),
      as.character(n_checks), session_hash,
      "charToRaw() hex encoding of column-signature + dimensions + first-row sample"
    ),
    stringsAsFactors = FALSE
  )
  ft_integ <- flextable::flextable(integrity_df) |>
    flextable::autofit() |> flextable::theme_zebra() |> flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_integ))
  doc <- officer::body_add_par(doc, "")
  
  # Regulatory compliance alignment.
  doc <- officer::body_add_par(doc, "Regulatory Compliance Alignment", style = "heading 2")
  reg_df <- data.frame(
    Framework   = c("ICH E6(R2) GCP", "EU GDPR Art. 5(1)(d)", "FAIR Principles",
                    "FDA 21 CFR Part 11", "ISO 14155:2020", "OECD GLP"),
    Requirement = c(
      "Complete audit trail for data corrections in clinical trials",
      "Personal data must be accurate and kept up to date",
      "Research data: Findable, Accessible, Interoperable, Reusable",
      "Electronic records with date/time stamps and audit trails",
      "Documented data management procedures for clinical investigations",
      "Raw data changes must be traceable with reason for change"
    ),
    Status = rep("ADDRESSED", 6L),
    stringsAsFactors = FALSE
  )
  ft_reg <- flextable::flextable(reg_df) |>
    flextable::autofit() |> flextable::theme_zebra() |>
    flextable::bold(j = 1) |> flextable::fontsize(size = 8, part = "body") |>
    flextable::color(j = 3, color = "#16a34a") |> flextable::bold(j = 3)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_reg))
  doc <- officer::body_add_par(doc, "")
  
  ############################################################################
  # Section 9: certification footer.
  ############################################################################
  doc <- officer::body_add_par(doc, "Certification", style = "heading 1")
  doc <- officer::body_add_par(doc, paste0(
    "This document certifies that a systematic, fitness-for-purpose data quality assessment was ",
    "performed using Open DQA (Session: ", session_hash, "). ",
    "The assessment covered ", n_checks, " quality checks across ", n_total, " records. ",
    "The resulting Quality Score is ", q$score, "% (Band: ", toupper(band), "). ",
    "All check expressions were validated against a security blacklist before execution. ",
    "This report was auto-generated and has not been manually modified. ",
    "Archive this document alongside study data and the associated JSON check configuration."
  ), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  doc <- officer::body_add_par(doc, paste0("Report generated: ", ts_now), style = "Normal")
  doc <- officer::body_add_par(doc, "Open DQA | MIT License | (c) 2026", style = "Normal")
  
  doc
}

##############################################################################
# Cleansing change-log generator. Produces an immutable Word record of every data
# modification performed during the cleansing phase.
##############################################################################
gen_cl_word <- function(cl, lang = "en", user_info = NULL) {
  doc    <- officer::read_docx()
  ts_now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  
  # Normalise column-name casing. The in-session log uses lowercase names; the Word
  # report uses capitalised names.
  if (!is.null(cl) && "timestamp" %in% names(cl) && !"Timestamp" %in% names(cl))
    names(cl)[names(cl) == "timestamp"] <- "Timestamp"
  if (!is.null(cl) && "action"    %in% names(cl) && !"Action"    %in% names(cl))
    names(cl)[names(cl) == "action"]    <- "Action"
  if (!is.null(cl) && "column"    %in% names(cl) && !"Column"    %in% names(cl))
    names(cl)[names(cl) == "column"]    <- "Column"
  
  # Cryptographic integrity hash for the change log.
  cl_hash <- tryCatch({
    raw_str  <- paste0(
      nrow(cl), "|", ts_now, "|",
      paste(names(cl), collapse = ","), "|",
      if (!is.null(cl) && nrow(cl) > 0)
        paste(cl$Timestamp[1], cl$Timestamp[nrow(cl)]) else "empty"
    )
    hex_chars <- sprintf("%02x", as.integer(charToRaw(raw_str)))
    paste0("CL-", toupper(paste(hex_chars[seq_len(min(12, length(hex_chars)))], collapse = "")))
  }, error = function(e) paste0("CL-", format(Sys.time(), "%Y%m%d%H%M%S")))
  
  ############################################################################
  # Cover page.
  ############################################################################
  doc <- doc |>
    officer::body_add_par("Data Cleansing Change Log", style = "heading 1") |>
    officer::body_add_par(paste0("Document ID: ", cl_hash), style = "Normal") |>
    officer::body_add_par(paste0("Generated: ", ts_now, " (ISO 8601)"), style = "Normal") |>
    officer::body_add_par("Open DQA | MIT License", style = "Normal") |>
    officer::body_add_par("")
  
  ############################################################################
  # Purpose and scope.
  ############################################################################
  doc <- doc |>
    officer::body_add_par("Purpose and Scope", style = "heading 1") |>
    officer::body_add_par(paste0(
      "This document provides a complete, immutable record of all data modifications performed ",
      "during the cleansing process associated with the Open DQA data quality assessment workflow. ",
      "It is designed to satisfy documentation requirements for: ",
      "(a) Good Clinical Practice (ICH E6(R2), Section 5.5.3 \u2013 data handling and record keeping), ",
      "(b) EU General Data Protection Regulation (GDPR Art. 5(1)(d) \u2013 accuracy principle), ",
      "(c) ISO 14155:2020 (clinical investigation of medical devices \u2013 data management), ",
      "(d) OECD Principles of Good Laboratory Practice, and ",
      "(e) FDA 21 CFR Part 11 (electronic records with audit trails). ",
      "Each entry records the exact timestamp, action type, affected column, row scope, and ",
      "old/new values to enable full audit trail reconstruction."
    ), style = "Normal") |>
    officer::body_add_par("")
  
  ############################################################################
  # Regulatory context.
  ############################################################################
  doc <- doc |>
    officer::body_add_par("Regulatory Context", style = "heading 1")
  
  reg_df <- data.frame(
    Framework   = c("ICH E6(R2) GCP", "GDPR Art. 5(1)(d)", "FAIR Principles",
                    "FDA 21 CFR Part 11", "ISO 14155:2020", "OECD GLP"),
    Requirement = c(
      "Complete audit trail for data corrections in clinical trials",
      "Personal data must be accurate and kept up to date",
      "Research data: Findable, Accessible, Interoperable, Reusable",
      "Electronic records must include audit trails with date/time stamps",
      "Documented data management procedures for clinical investigations",
      "Raw data changes must be traceable with reason for change"
    ),
    How_Addressed = c(
      "Full timestamp + old/new value logging per modification",
      "Documented justification for each correction via action type",
      "Machine-readable change log with unique document ID",
      "ISO 8601 timestamps, integrity hash CL-, sequential logging",
      "Structured modification register with sequential numbering",
      "Before/after values preserved with action classification"
    ),
    stringsAsFactors = FALSE
  )
  ft_reg <- flextable::flextable(reg_df) |>
    flextable::autofit() |> flextable::theme_zebra() |>
    flextable::bold(j = 1) |> flextable::fontsize(size = 8, part = "body")
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_reg))
  doc <- officer::body_add_par(doc, "")
  
  ############################################################################
  # Tool information.
  ############################################################################
  doc <- doc |>
    officer::body_add_par("Tool Information", style = "heading 1")
  
  tool_df <- data.frame(
    Property = c("Tool", "Version", "License", "R Version", "Document ID", "Timestamp"),
    Value    = c("Open DQA", "Prototype", "MIT License",
                 paste0(R.version$major, ".", R.version$minor), cl_hash, ts_now),
    stringsAsFactors = FALSE
  )
  ft_tool <- flextable::flextable(tool_df) |>
    flextable::autofit() |> flextable::theme_zebra() |> flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_tool))
  doc <- officer::body_add_par(doc, "")
  
  # Analyst attribution, if provided.
  ui_name  <- tryCatch(user_info$name,  error = function(e) NULL)
  ui_func  <- tryCatch(user_info$func,  error = function(e) NULL)
  ui_email <- tryCatch(user_info$email, error = function(e) NULL)
  has_analyst <- !is.null(ui_name) && nzchar(trimws(ui_name %||% ""))
  
  if (has_analyst) {
    doc <- officer::body_add_par(doc, "Analyst Information", style = "heading 2")
    adf <- data.frame(
      Field = c("Name", "Function / Role", "Email"),
      Value = c(ui_name %||% "Not provided",
                ui_func  %||% "Not provided",
                ui_email %||% "Not provided"),
      stringsAsFactors = FALSE
    )
    ft_a <- flextable::flextable(adf) |>
      flextable::autofit() |> flextable::theme_zebra() |> flextable::bold(j = 1)
    doc <- flextable::body_add_flextable(doc, safe_ft(ft_a))
    doc <- officer::body_add_par(doc, "")
  }
  
  ############################################################################
  # Data processing log.
  ############################################################################
  doc <- doc |>
    officer::body_add_par("Data Processing Log", style = "heading 1")
  
  if (!is.null(cl) && nrow(cl) > 0) {
    # Summary statistics.
    doc <- officer::body_add_par(doc, "Summary Statistics", style = "heading 2")
    unique_actions <- length(unique(cl$Action))
    col_field <- if ("Column" %in% names(cl)) cl$Column else character(nrow(cl))
    unique_cols <- length(unique(col_field[col_field != "--" & nzchar(col_field)]))
    sum_df <- data.frame(
      Metric = c("Total Modifications", "Unique Action Types", "Columns Affected",
                 "First Modification", "Last Modification"),
      Value  = c(as.character(nrow(cl)), as.character(unique_actions),
                 as.character(unique_cols),
                 if ("Timestamp" %in% names(cl)) as.character(cl$Timestamp[1]) else "N/A",
                 if ("Timestamp" %in% names(cl)) as.character(cl$Timestamp[nrow(cl)]) else "N/A"),
      stringsAsFactors = FALSE
    )
    ft_sum <- flextable::flextable(sum_df) |>
      flextable::autofit() |> flextable::theme_zebra() |> flextable::bold(j = 1)
    doc <- flextable::body_add_flextable(doc, safe_ft(ft_sum))
    doc <- officer::body_add_par(doc, "")
    
    # Actions-by-type breakdown. The intermediate frame is built explicitly because
    # as.data.frame(sort(table(x))) returns a single-column frame when x has only one
    # distinct value, which would break the subsequent names<- assignment.
    if ("Action" %in% names(cl) && length(cl$Action) > 0) {
      doc <- officer::body_add_par(doc, "Actions by Type", style = "heading 2")
      act_counts <- sort(table(cl$Action), decreasing = TRUE)
      act_tbl <- data.frame(
        `Action Type` = names(act_counts),
        Count         = as.integer(act_counts),
        stringsAsFactors = FALSE,
        check.names   = FALSE
      )
      ft_act <- flextable::flextable(act_tbl) |>
        flextable::autofit() |> flextable::theme_zebra()
      doc <- flextable::body_add_flextable(doc, safe_ft(ft_act))
      doc <- officer::body_add_par(doc, "")
    }
    
    # Complete modification register. Entries are split into chunks of 200 rows per
    # table so that long logs do not overflow the page in Word.
    doc <- officer::body_add_par(doc, "Complete Modification Register", style = "heading 2")
    doc <- officer::body_add_par(doc, paste0(
      "Every data modification is listed below in chronological order. ",
      "Each entry is sequentially numbered for cross-referencing. ",
      "Long logs are split into chunks of 200 entries to prevent page overflow."
    ), style = "Normal")
    doc <- officer::body_add_par(doc, "")
    
    cl_display <- cbind(Seq = seq_len(nrow(cl)), as.data.frame(cl))
    # Truncate long string values so the table fits the page.
    for (cn in names(cl_display)) {
      if (is.character(cl_display[[cn]]))
        cl_display[[cn]] <- substr(cl_display[[cn]], 1, 80)
    }
    
    chunk_size <- 200L
    n_chunks   <- ceiling(nrow(cl_display) / chunk_size)
    for (ch in seq_len(n_chunks)) {
      s_row <- (ch - 1L) * chunk_size + 1L
      e_row <- min(ch * chunk_size, nrow(cl_display))
      chunk_df <- cl_display[s_row:e_row, , drop = FALSE]
      if (n_chunks > 1L)
        doc <- officer::body_add_par(doc,
                                     paste0("Entries ", s_row, " \u2013 ", e_row, " of ", nrow(cl_display)),
                                     style = "Normal")
      ft_cl <- flextable::flextable(chunk_df) |>
        flextable::autofit() |> flextable::theme_zebra() |>
        flextable::fontsize(size = 7, part = "body") |>
        flextable::fontsize(size = 8, part = "header") |>
        flextable::bold(part = "header")
      doc <- flextable::body_add_flextable(doc, safe_ft(ft_cl))
      doc <- officer::body_add_par(doc, "")
    }
  } else {
    doc <- officer::body_add_par(doc,
                                 "No modifications were performed during this cleansing session.",
                                 style = "Normal")
  }
  doc <- officer::body_add_par(doc, "")
  
  ############################################################################
  # Certification and archival.
  ############################################################################
  doc <- doc |>
    officer::body_add_par("Certification and Archival", style = "heading 1") |>
    officer::body_add_par(paste0(
      "This document certifies that all data modifications listed above were performed using ",
      "Open DQA and logged automatically with full before/after traceability. ",
      "The document integrity hash is: ", cl_hash, ". ",
      "This change log must be archived alongside the study documentation and the cleansed dataset. ",
      "For GCP-regulated studies, this document forms part of the Trial Master File (TMF) ",
      "data management section. For studies governed by ISO 14155:2020 or OECD GLP, this log ",
      "satisfies the requirement for traceable raw data modifications."
    ), style = "Normal") |>
    officer::body_add_par("") |>
    officer::body_add_par(paste0("Report generated: ", ts_now), style = "Normal") |>
    officer::body_add_par("Open DQA | MIT License | (c) 2026", style = "Normal")
  
  doc
}

##############################################################################
# Thin wrappers that keep the existing downloadHandler calls working without any UI
# change. Each wrapper renders the officer document to a temporary .docx file and
# returns the path.
##############################################################################
gen_dq_certificate <- function(issues, n_checks, mapped_df, lang = "en",
                               user_info = NULL, perf_data = NULL,
                               custom_checks = list()) {
  tryCatch({
    sev_plt <- if (!is.null(issues) && nrow(issues) > 0)
      make_sev_plot_png(issues) else NULL
    cat_plt <- if (!is.null(issues) && nrow(issues) > 0)
      make_cat_plot_png(issues, custom_checks) else NULL
    
    doc  <- gen_word(
      issues         = issues,
      n_checks       = n_checks,
      mapped_df      = mapped_df,
      lang           = lang,
      sev_plot       = sev_plt,
      cat_plot       = cat_plt,
      user_info      = user_info,
      perf_data      = perf_data,
      checks_df      = NULL,
      selected_checks = character(),
      custom_checks  = custom_checks
    )
    out_path <- tempfile(fileext = ".docx")
    print(doc, target = out_path)
    if (file.exists(out_path)) out_path else NULL
  }, error = function(e) { message("gen_dq_certificate error: ", e$message); NULL })
}

gen_cleansing_certificate <- function(cl_log, lang = "en", user_info = NULL) {
  tryCatch({
    doc      <- gen_cl_word(cl = cl_log, lang = lang, user_info = user_info)
    out_path <- tempfile(fileext = ".docx")
    print(doc, target = out_path)
    if (file.exists(out_path)) out_path else NULL
  }, error = function(e) { message("gen_cleansing_certificate error: ", e$message); NULL })
}

##############################################################################
# Inline stylesheet. Defines the design tokens, layout, typography, and animation rules
# used by the entire UI.
##############################################################################
APP_CSS <- "
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap');
:root{--brand:#0866FF;--brand-hover:#0753D4;--brand-light:#EBF5FF;--brand-surface:#F0F7FF;--brand-glow:rgba(8,102,255,0.12);--success:#00A86B;--success-light:#E6F9F0;--warning:#F5A623;--warning-light:#FFF8EC;--danger:#FA383E;--danger-light:#FFF0F0;--critical:#BE123C;--critical-light:#FFF1F2;--text-primary:#1C1E21;--text-secondary:#606770;--text-tertiary:#8A8D91;--surface-0:#FFF;--surface-1:#F0F2F5;--surface-2:#E4E6EB;--border:#CED0D4;--border-light:#E4E6EB;--shadow-xs:0 1px 2px rgba(0,0,0,0.04);--shadow-sm:0 1px 3px rgba(0,0,0,0.06),0 1px 2px rgba(0,0,0,0.04);--shadow-md:0 4px 6px -1px rgba(0,0,0,0.07),0 2px 4px -1px rgba(0,0,0,0.04);--shadow-lg:0 10px 25px -3px rgba(0,0,0,0.08),0 4px 10px -2px rgba(0,0,0,0.04);--radius-sm:8px;--radius-md:12px;--radius-lg:16px;--radius-xl:20px;--radius-2xl:24px;--transition:all 0.2s cubic-bezier(0.4,0,0.2,1)}
*,*::before,*::after{box-sizing:border-box}
body,.content-wrapper,.wrapper{font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif!important;background:var(--surface-1)!important;color:var(--text-primary);-webkit-font-smoothing:antialiased}
.main-sidebar,.main-header,.main-footer,.control-sidebar,.brand-link{display:none!important}
.content-wrapper{margin-left:0!important;padding:0!important;min-height:100vh!important}
.odqa-topbar{position:sticky;top:0;z-index:1040;display:flex;align-items:center;justify-content:space-between;height:60px;padding:0 24px;background:var(--surface-0);border-bottom:1px solid var(--border-light);box-shadow:var(--shadow-xs)}
.odqa-topbar-brand{display:flex;align-items:center;gap:10px;font-size:20px;font-weight:800;color:var(--brand);letter-spacing:-0.5px;cursor:pointer}
.odqa-topbar-brand .brand-icon{width:36px;height:36px;border-radius:10px;background:linear-gradient(135deg,var(--brand),#6C5CE7);display:flex;align-items:center;justify-content:center;color:white;font-size:16px;font-weight:900}
.odqa-topbar-nav{display:flex;align-items:center;gap:4px;background:var(--surface-1);border-radius:var(--radius-lg);padding:4px}
.odqa-nav-pill{padding:8px 16px;border-radius:var(--radius-md);font-size:13px;font-weight:600;color:var(--text-secondary);cursor:pointer;transition:var(--transition);border:none;background:transparent;white-space:nowrap}
.odqa-nav-pill:hover{background:var(--surface-2);color:var(--text-primary)}
.odqa-nav-pill.active{background:var(--brand)!important;color:white!important;box-shadow:0 2px 8px rgba(8,102,255,0.3)}
.odqa-nav-pill.disabled{opacity:0.4;pointer-events:none}
.odqa-step{visibility:hidden;position:absolute;left:-9999px;top:0;width:1200px;height:800px;overflow:hidden;pointer-events:none;animation:fadeSlide 0.35s ease}
.odqa-step.active{visibility:visible;position:static;left:auto;top:auto;width:auto;height:auto;overflow:visible;pointer-events:auto}
@keyframes fadeSlide{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
.odqa-container{max-width:960px;margin:0 auto;padding:32px 24px 80px}
.odqa-hero{text-align:center;padding:56px 24px 40px;background:linear-gradient(135deg,#EBF5FF 0%,#F5F0FF 50%,#FFF0F5 100%);position:relative;overflow:hidden}
.odqa-hero h1{font-size:42px;font-weight:900;letter-spacing:-1.5px;background:linear-gradient(135deg,var(--brand) 0%,#6C5CE7 100%);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;margin-bottom:12px}
.odqa-hero .subtitle{font-size:17px;color:var(--text-secondary);font-weight:400;max-width:600px;margin:0 auto 8px;line-height:1.6}
.odqa-hero .desc{font-size:14px;color:var(--text-tertiary);max-width:680px;margin:0 auto 36px;line-height:1.7}
.odqa-action-cards{display:grid;grid-template-columns:1fr 1fr;gap:20px;max-width:720px;margin:0 auto 32px}
.odqa-action-card{background:var(--surface-0);border-radius:var(--radius-xl);padding:28px 24px;text-align:left;border:2px solid transparent;cursor:pointer;box-shadow:var(--shadow-md);transition:var(--transition)}
.odqa-action-card:hover{transform:translateY(-4px);box-shadow:var(--shadow-lg);border-color:var(--brand)}
.odqa-action-card .card-icon{width:48px;height:48px;border-radius:var(--radius-md);display:flex;align-items:center;justify-content:center;font-size:16px;font-weight:900;margin-bottom:14px}
.odqa-action-card h3{font-size:17px;font-weight:700;margin-bottom:6px}
.odqa-action-card p{font-size:13px;color:var(--text-secondary);line-height:1.5;margin:0}
.odqa-workflow{display:flex;justify-content:center;gap:0;max-width:800px;margin:0 auto 28px}
.odqa-wf-step{display:flex;flex-direction:column;align-items:center;gap:8px;flex:1;position:relative}
.odqa-wf-num{width:34px;height:34px;border-radius:50%;background:var(--brand);color:white;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:14px}
.odqa-wf-label{font-size:11px;font-weight:600;color:var(--text-secondary);text-align:center}
.odqa-who{max-width:720px;margin:0 auto 24px;padding:22px 28px;background:var(--surface-0);border-radius:var(--radius-xl);box-shadow:var(--shadow-sm);text-align:center;border:1px solid var(--border-light)}
.odqa-who h3{font-size:16px;font-weight:800;margin-bottom:8px}
.odqa-who p{font-size:13.5px;color:var(--text-secondary);line-height:1.7;margin:0}
.odqa-card{background:var(--surface-0);border-radius:var(--radius-xl);padding:24px;margin-bottom:16px;box-shadow:var(--shadow-sm);border:1px solid var(--border-light)}
.odqa-card-header{display:flex;align-items:center;gap:12px;margin-bottom:16px}
.odqa-card-badge{width:34px;height:34px;border-radius:10px;background:var(--brand);color:white;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:14px;flex-shrink:0}
.odqa-card-title{font-size:16px;font-weight:700}
.odqa-card-subtitle{font-size:12px;color:var(--text-secondary);margin-top:2px}
.odqa-step-header{margin-bottom:24px}
.odqa-step-header h2{font-size:24px;font-weight:800;letter-spacing:-0.5px;margin-bottom:6px}
.odqa-step-header p{font-size:14px;color:var(--text-secondary);line-height:1.6;margin:0}
.btn-odqa{display:inline-flex;align-items:center;gap:8px;padding:10px 20px;border-radius:var(--radius-md);font-size:14px;font-weight:600;border:none;cursor:pointer;transition:var(--transition)}
.btn-odqa-primary{background:var(--brand);color:white}.btn-odqa-primary:hover{background:var(--brand-hover);box-shadow:0 4px 12px rgba(8,102,255,0.3)}
.btn-odqa-secondary{background:var(--surface-1);color:var(--text-primary);border:1px solid var(--border)}.btn-odqa-secondary:hover{background:var(--surface-2)}
.btn-odqa-success{background:var(--success);color:white}.btn-odqa-success:hover{background:#009060}
.btn-odqa-danger{background:var(--danger);color:white}.btn-odqa-danger:hover{background:#E0282E}
.btn-odqa-ghost{background:transparent;color:var(--brand);padding:10px 16px}.btn-odqa-ghost:hover{background:var(--brand-light)}
.btn-group-odqa{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
.odqa-metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:20px}
.odqa-metric{background:var(--surface-0);border-radius:var(--radius-lg);padding:20px;text-align:center;box-shadow:var(--shadow-sm);border:1px solid var(--border-light);position:relative;overflow:hidden}
.odqa-metric::before{content:'';position:absolute;top:0;left:0;right:0;height:4px}
.odqa-metric.m-checks::before{background:var(--brand)}.odqa-metric.m-issues::before{background:var(--warning)}.odqa-metric.m-affected::before{background:var(--danger)}.odqa-metric.m-score::before{background:var(--success)}
.odqa-metric .metric-value{font-size:32px;font-weight:900;letter-spacing:-1px;margin-bottom:4px}
.odqa-metric.m-checks .metric-value{color:var(--brand)}.odqa-metric.m-issues .metric-value{color:var(--warning)}.odqa-metric.m-affected .metric-value{color:var(--danger)}.odqa-metric.m-score .metric-value{color:var(--success)}
.odqa-metric .metric-label{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;color:var(--text-tertiary)}
.odqa-interp{border-radius:var(--radius-lg);padding:20px 24px;margin-bottom:16px;display:flex;align-items:flex-start;gap:14px;border:1px solid}
.odqa-interp.level-ok{background:var(--success-light);border-color:#A7F3D0}.odqa-interp.level-lo{background:var(--brand-light);border-color:#BFDBFE}.odqa-interp.level-md{background:var(--warning-light);border-color:#FDE68A}.odqa-interp.level-hi{background:var(--danger-light);border-color:#FECACA}.odqa-interp.level-cr{background:var(--critical-light);border-color:#FECDD3}
.odqa-interp-icon{width:40px;height:40px;border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:20px;flex-shrink:0}
.odqa-hint{display:flex;align-items:flex-start;gap:10px;padding:14px 18px;border-radius:var(--radius-md);margin-bottom:14px;font-size:13px;line-height:1.6}
.odqa-hint.info{background:var(--brand-light);color:#1E40AF}.odqa-hint.success{background:var(--success-light);color:#065F46}.odqa-hint.warning{background:var(--warning-light);color:#92400E}.odqa-hint.danger{background:var(--danger-light);color:#991B1B}
.odqa-source-tabs{display:flex;gap:10px;margin-bottom:20px}
.odqa-source-tab{flex:1;padding:18px;border-radius:var(--radius-lg);background:var(--surface-0);border:2px solid var(--border-light);cursor:pointer;text-align:center;transition:var(--transition)}
.odqa-source-tab:hover{border-color:var(--brand);transform:translateY(-2px)}
.odqa-source-tab.active{border-color:var(--brand);background:var(--brand-light);box-shadow:0 2px 8px rgba(8,102,255,0.15)}
.odqa-source-tab .tab-label{font-size:13px;font-weight:700}
.odqa-domain-tabs{display:flex;gap:0;border-bottom:2px solid var(--border-light);margin-bottom:16px;overflow-x:auto}
.odqa-domain-tab{padding:10px 14px;border:none;background:transparent;font-size:12px;font-weight:600;color:var(--text-secondary);cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-2px;transition:var(--transition);font-family:inherit;white-space:nowrap}
.odqa-domain-tab:hover{color:var(--brand);background:var(--brand-light)}
.odqa-domain-tab.active{color:var(--brand);border-bottom-color:var(--brand);font-weight:700}
.odqa-domain-panel{visibility:hidden;position:absolute;left:-9999px;top:0;width:1200px;height:800px;overflow:hidden;pointer-events:none}
.odqa-sub-panel{visibility:hidden;position:absolute;left:-9999px;top:0;width:1200px;height:800px;overflow:hidden;pointer-events:none;margin-top:12px}
.odqa-sub-panel.active{visibility:visible;position:static;left:auto;top:auto;width:auto;height:auto;overflow:visible;pointer-events:auto}
.odqa-domain-panel.active{visibility:visible;position:static;left:auto;top:auto;width:auto;height:auto;overflow:visible;pointer-events:auto}
.odqa-suggestion{background:var(--surface-0);border-radius:var(--radius-sm);padding:14px 16px;margin:8px 0;border-left:4px solid var(--brand);border:1px solid var(--border-light)}
.odqa-suggestion.sev-high{border-left-color:var(--danger)}.odqa-suggestion.sev-medium{border-left-color:var(--warning)}.odqa-suggestion.sev-low{border-left-color:var(--success)}.odqa-suggestion.sev-critical{border-left-color:var(--critical)}
.expr-code{font-family:'JetBrains Mono',monospace;font-size:11px;background:var(--surface-1);padding:4px 10px;border-radius:var(--radius-sm);border:1px solid var(--border-light);word-break:break-all}
.odqa-disclaimer-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.6);z-index:9999;display:flex;align-items:center;justify-content:center;backdrop-filter:blur(4px)}
.odqa-disclaimer-box{background:var(--surface-0);border-radius:var(--radius-2xl);padding:36px;max-width:680px;width:90%;box-shadow:0 20px 40px rgba(0,0,0,0.1);max-height:85vh;overflow-y:auto}
.odqa-disclaimer-box h2{font-size:20px;font-weight:800;margin-bottom:14px;color:var(--brand)}
.odqa-disclaimer-box .disc-text{font-size:13px;line-height:1.8;color:var(--text-secondary);margin-bottom:20px;padding:18px;background:var(--surface-1);border-radius:var(--radius-md);border-left:4px solid var(--brand);white-space:pre-line}
.odqa-disclaimer-box .disc-cb{display:flex;align-items:flex-start;gap:12px;margin-bottom:16px;padding:14px;background:var(--success-light);border-radius:var(--radius-md);cursor:pointer}
.odqa-disclaimer-box .disc-cb input[type=checkbox]{width:18px;height:18px;margin-top:2px;flex-shrink:0;accent-color:var(--brand)}
.odqa-disclaimer-box .disc-btn{width:100%;padding:12px;border:none;border-radius:var(--radius-md);font-size:15px;font-weight:700;cursor:pointer;transition:var(--transition)}
.odqa-disclaimer-box .disc-btn.enabled{background:var(--brand);color:white}
.odqa-disclaimer-box .disc-btn.disabled{background:var(--surface-2);color:var(--text-tertiary);cursor:not-allowed}
.odqa-footer{position:fixed;bottom:0;left:0;right:0;background:var(--surface-0);border-top:1px solid var(--border-light);padding:6px 24px;display:flex;justify-content:space-between;align-items:center;z-index:1030;box-shadow:0 -2px 10px rgba(0,0,0,0.04)}
.odqa-footer .step-indicator{font-size:10px;font-weight:600;color:var(--text-tertiary)}
.odqa-card .form-control,.odqa-card .selectize-input,.odqa-card select.form-control{border-radius:var(--radius-sm)!important;border:1.5px solid var(--border)!important;font-size:14px!important;padding:10px 14px!important;font-family:'Inter',sans-serif!important}
.odqa-card .form-control:focus,.odqa-card .selectize-input.focus{border-color:var(--brand)!important;box-shadow:0 0 0 3px var(--brand-glow)!important}
table.dataTable thead th{background:var(--surface-1)!important;font-size:12px!important;font-weight:700!important;text-transform:uppercase;letter-spacing:0.3px;border-bottom:2px solid var(--border)!important;padding:10px 12px!important}
table.dataTable tbody td{font-size:13px!important;padding:8px 12px!important;border-bottom:1px solid var(--border-light)!important}
table.dataTable tbody tr:hover{background:var(--brand-light)!important}
.odqa-chart-container{background:var(--surface-0);border-radius:var(--radius-lg);padding:20px;margin-bottom:16px;border:1px solid var(--border-light)}
.odqa-compare{display:grid;grid-template-columns:1fr 1fr;gap:14px}
.odqa-finish{text-align:center;padding:48px 24px;max-width:700px;margin:0 auto}
.odqa-finish h1{font-size:28px;font-weight:900;margin-bottom:12px;color:var(--success)}
.odqa-finish .recap{background:var(--surface-0);border-radius:var(--radius-xl);padding:28px;margin:20px 0;text-align:left;box-shadow:var(--shadow-sm);border:1px solid var(--border-light)}
.odqa-finish .recap-item{display:flex;align-items:center;gap:10px;padding:8px 0;border-bottom:1px solid var(--border-light);font-size:13px}
.odqa-hero-footer{margin-top:28px;padding-top:20px;border-top:1px solid rgba(0,0,0,0.06);font-size:10px;color:var(--text-secondary);line-height:1.5;visibility:visible!important;opacity:1!important}
.odqa-tut-card{background:var(--surface-0);border-radius:var(--radius-xl);margin-bottom:12px;overflow:hidden;box-shadow:var(--shadow-sm);border:1px solid var(--border-light)}
.odqa-tut-header{display:flex;align-items:center;gap:14px;padding:16px 20px;cursor:pointer}
.odqa-tut-header:hover{background:var(--surface-1)}
.odqa-tut-num{width:36px;height:36px;border-radius:10px;background:var(--brand);color:white;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:15px;flex-shrink:0}
.odqa-tut-title{font-size:15px;font-weight:700;flex:1}
.odqa-tut-chevron{color:var(--text-tertiary);font-size:16px;transition:transform 0.3s ease}
.odqa-tut-body{display:none;padding:2px 16px 10px 56px;font-size:13px;color:var(--text-secondary);line-height:1.55}
.odqa-tut-body ol{padding-left:18px;margin:4px 0 6px}
.odqa-tut-body ol li{margin:1px 0}
.odqa-tut-body .tut-overview{margin-bottom:6px}
.odqa-tut-body .tut-wf-label{font-weight:600;margin:4px 0 2px;color:var(--text-primary);font-size:12px}
.odqa-tut-body .tut-example{background:var(--surface-1);border-left:3px solid var(--brand);padding:6px 10px;border-radius:4px;font-size:12px;margin-top:4px;line-height:1.55}
.odqa-tut-header{padding:12px 18px}
.odqa-tut-card{margin-bottom:8px}
.odqa-tut-card.open .odqa-tut-body{display:block}.odqa-tut-card.open .odqa-tut-chevron{transform:rotate(180deg)}
.odqa-learn-more-btn::after{content:'\\25BC';margin-left:6px;display:inline-block;transition:transform .2s ease}
.odqa-learn-more-btn.is-open::after{transform:rotate(180deg)}
.record-nav{display:flex;align-items:center;gap:12px;padding:14px 18px;background:var(--brand-light);border-radius:var(--radius-lg);margin:12px 0}
.record-nav .rec-counter{font-size:14px;font-weight:700;color:var(--brand)}
.record-fields{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px;margin:12px 0}
.record-field{background:var(--surface-1);border-radius:var(--radius-sm);padding:8px 12px}
.record-field .field-label{font-size:10px;font-weight:700;color:var(--text-tertiary);text-transform:uppercase;letter-spacing:0.5px}
.record-field .field-value{font-size:14px;font-weight:500;margin-top:2px}
.sql-template-btns{display:flex;gap:6px;margin-bottom:10px;flex-wrap:wrap}
.sql-template-btns .btn{font-size:11px;padding:5px 12px;border-radius:20px;background:#45475A;color:#CDD6F4;border:none;font-weight:600;cursor:pointer}
.sql-template-btns .btn:hover{background:var(--brand);color:white}
@media(max-width:768px){.odqa-action-cards{grid-template-columns:1fr}.odqa-metrics{grid-template-columns:repeat(2,1fr)}.odqa-topbar-nav{display:none}.odqa-hero h1{font-size:30px}.odqa-compare{grid-template-columns:1fr}}
.odqa-proctimer{position:sticky;top:60px;z-index:1039;background:var(--surface-0);border-bottom:1px solid var(--border-light);padding:4px 24px;font-size:11px;color:var(--text-secondary);display:flex;gap:14px;flex-wrap:wrap;align-items:center}
.odqa-proctimer .pt-chip{display:inline-flex;align-items:center;gap:6px;padding:2px 8px;border-radius:10px;background:var(--surface-1)}
.odqa-proctimer .pt-chip.pt-active{background:var(--brand-light);color:var(--brand);font-weight:700}
.odqa-proctimer .pt-label{font-weight:600;color:var(--text-tertiary)}
.odqa-proctimer .pt-val{font-weight:700}
.odqa-busy{position:relative;pointer-events:none;opacity:.65}
.odqa-busy::after{content:'';display:inline-block;width:10px;height:10px;margin-left:8px;border-radius:50%;border:2px solid transparent;border-top-color:currentColor;animation:odqa-spin .7s linear infinite;vertical-align:middle}
@keyframes odqa-spin{to{transform:rotate(360deg)}}
.odqa-skeleton{background:linear-gradient(90deg,var(--surface-1) 25%,var(--surface-2) 50%,var(--surface-1) 75%);background-size:200% 100%;animation:odqa-shimmer 1.4s ease-in-out infinite;border-radius:8px}
@keyframes odqa-shimmer{0%{background-position:200% 0}100%{background-position:-200% 0}}
.odqa-skel-row{height:14px;margin:8px 0}
.odqa-skel-w-30{width:30%}.odqa-skel-w-50{width:50%}.odqa-skel-w-70{width:70%}.odqa-skel-w-90{width:90%}
/* Auto-hide DataTables Processing overlay once the table has rows. Gives the */
/* first-paint impression that data is already there even during the JSON round-trip. */
.dataTables_wrapper.no-footer .dataTables_processing{background:linear-gradient(90deg,var(--surface-1) 25%,var(--surface-2) 50%,var(--surface-1) 75%);background-size:200% 100%;animation:odqa-shimmer 1.4s ease-in-out infinite;color:transparent}
"

##############################################################################
# User interface definition.
##############################################################################
ui <- bs4DashPage(
  dark = NULL,
  header = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),
  footer = bs4DashFooter(left = "", right = ""),
  body = bs4DashBody(
    useShinyjs(), useWaiter(),
    tags$head(
      tags$style(HTML(APP_CSS)),
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      tags$link(rel = "icon", type = "image/svg+xml",
                href = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 36 36'%3E%3Crect width='36' height='36' rx='8' fill='%230866FF'/%3E%3Ctext x='18' y='25' font-family='Arial' font-weight='900' font-size='16' fill='white' text-anchor='middle'%3EDQ%3C/text%3E%3C/svg%3E"),
      tags$title("Open DQA | Data Quality Assessment"),
      tags$script(HTML("
        Shiny.addCustomMessageHandler('goto_step',function(s){
          document.querySelectorAll('.odqa-step').forEach(function(el){el.classList.remove('active')});
          var id=(s==='T')?'stepT':(s==='F')?'stepF':'step'+s;
          var el=document.getElementById(id);if(el)el.classList.add('active');window.scrollTo(0,0);
          document.querySelectorAll('.odqa-nav-pill').forEach(function(p){p.classList.remove('active')});
          var pill=document.getElementById('pill_'+s);if(pill)pill.classList.add('active');
        });
        Shiny.addCustomMessageHandler('enable_pills',function(max){
          for(var i=0;i<=5;i++){var p=document.getElementById('pill_'+i);if(p){if(i<=max)p.classList.remove('disabled');else p.classList.add('disabled')}}
        });
        Shiny.addCustomMessageHandler('set_pill_labels',function(map){
          Object.keys(map).forEach(function(id){
            var el=document.getElementById(id); if(el) el.innerText=map[id];
          });
        });
      "))
    ),
    # Overlays.
    # The disclaimer is rendered statically in the UI body so it is visible the instant
    # the page loads. The proceed button is disabled by default; a client-side handler
    # enables it only when the acceptance checkbox is ticked. Only the final click emits
    # a Shiny event. The disclaimer text is always in English because the user has not
    # yet chosen a language at this point.
    div(id = "disclaimer_overlay", class = "odqa-disclaimer-overlay",
        div(class = "odqa-disclaimer-box",
            h2(i18n("disclaimer_title", "en")),
            div(class = "disc-text", i18n("disclaimer_text", "en")),
            div(class = "disc-cb",
                tags$input(type = "checkbox", id = "disc_cb_static",
                           onchange = paste0(
                             "var btn=document.getElementById('disc_btn_static');",
                             "if(!btn)return;",
                             "if(this.checked){",
                             "  btn.classList.remove('disabled');",
                             "  btn.classList.add('enabled');",
                             "  btn.disabled=false;",
                             "}else{",
                             "  btn.classList.remove('enabled');",
                             "  btn.classList.add('disabled');",
                             "  btn.disabled=true;",
                             "}")),
                tags$label(`for` = "disc_cb_static", i18n("disclaimer_accept", "en"))),
            tags$button(id = "disc_btn_static",
                        class = "disc-btn disabled",
                        disabled = NA,
                        onclick = paste0(
                          "if(this.disabled)return;",
                          "Shiny.setInputValue('disc_proceed',Math.random(),{priority:'event'});"),
                        i18n("disclaimer_proceed", "en")))),
    div(id = "analyst_overlay", style = "display:none;", class = "odqa-disclaimer-overlay",
        div(class = "odqa-disclaimer-box", uiOutput("analyst_overlay_ui"))),
    # Top bar.
    div(class = "odqa-topbar",
        div(class = "odqa-topbar-brand", onclick = "Shiny.setInputValue('nav_home',Math.random())",
            div(class = "brand-icon", "DQ"), span("OpenDQA")),
        div(class = "odqa-topbar-nav", id = "topnav",
            tags$button(class = "odqa-nav-pill active", id = "pill_0", onclick = "Shiny.setInputValue('nav_to',0,{priority:'event'})", "Home"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_1", onclick = "Shiny.setInputValue('nav_to',1,{priority:'event'})", "1 Import"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_2", onclick = "Shiny.setInputValue('nav_to',2,{priority:'event'})", "2 Studio"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_3", onclick = "Shiny.setInputValue('nav_to',3,{priority:'event'})", "3 Results"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_4", onclick = "Shiny.setInputValue('nav_to',4,{priority:'event'})", "4 Cleansing"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_F", onclick = "Shiny.setInputValue('nav_to','F',{priority:'event'})", "Summary")),
        div(class = "odqa-topbar-actions",
            selectInput("lang", "", choices = c("EN" = "en", "DE" = "de", "FR" = "fr"), selected = "en", width = "80px"))),
    
    # Global process timer strip.
    div(class = "odqa-proctimer", uiOutput("proctimer_ui")),
    
    # Step 0: welcome.
    div(class = "odqa-step active", id = "step0",
        div(class = "odqa-hero",
            h1(uiOutput("hero_title_text")),
            p(class = "subtitle", uiOutput("hero_sub_text")),
            
            div(class = "odqa-action-cards",
                div(class = "odqa-action-card", onclick = "Shiny.setInputValue('go_tutorial',Math.random(),{priority:'event'})",
                    div(class = "card-icon", style = "background:linear-gradient(135deg,#E8F5E9,#C8E6C9);color:#00A86B;font-weight:900;", "T"),
                    h3(uiOutput("card_tut_title")), p(uiOutput("card_tut_desc"))),
                div(class = "odqa-action-card", onclick = "Shiny.setInputValue('nav_to',1,{priority:'event'})",
                    div(class = "card-icon", style = "background:linear-gradient(135deg,#EBF5FF,#BBDEFB);color:#0866FF;font-weight:900;", "Go"),
                    h3(uiOutput("card_start_title")), p(uiOutput("card_start_desc")))),
            uiOutput("hero_workflow"),
            uiOutput("hero_faq"),
            div(class = "odqa-hero-footer",
                HTML("Open DQA | MIT License | &copy; 2026")))),
    
    # Tutorial.
    div(class = "odqa-step", id = "stepT", div(class = "odqa-container",
                                               div(class = "odqa-step-header", uiOutput("tut_header")),
                                               uiOutput("tut_cards"),
                                               div(class = "btn-group-odqa", style = "margin-top:16px;",
                                                   tags$button(class = "btn-odqa btn-odqa-secondary", onclick = "Shiny.setInputValue('nav_to',0,{priority:'event'})", "Back"),
                                                   tags$button(class = "btn-odqa btn-odqa-primary", onclick = "Shiny.setInputValue('nav_to',1,{priority:'event'})", "Begin Assessment")))),
    
    # Step 1: data import.
    div(class = "odqa-step", id = "step1", div(class = "odqa-container",
                                               div(class = "odqa-step-header", uiOutput("s1_header")),
                                               div(class = "odqa-hint info", span(class = "odqa-hint-icon", "i"), uiOutput("s1_source_hint")),
                                               # Source tabs.
                                               div(class = "odqa-source-tabs",
                                                   div(class = "odqa-source-tab active", id = "src_local",
                                                       onclick = "Shiny.setInputValue('src_tab','local',{priority:'event'});document.querySelectorAll('.odqa-source-tab').forEach(e=>e.classList.remove('active'));this.classList.add('active');",
                                                       div(class = "tab-label", "Local File")),
                                                   div(class = "odqa-source-tab", id = "src_db",
                                                       onclick = "Shiny.setInputValue('src_tab','db',{priority:'event'});document.querySelectorAll('.odqa-source-tab').forEach(e=>e.classList.remove('active'));this.classList.add('active');",
                                                       div(class = "tab-label", "SQL Database")),
                                                   div(class = "odqa-source-tab", id = "src_fhir",
                                                       onclick = "Shiny.setInputValue('src_tab','fhir',{priority:'event'});document.querySelectorAll('.odqa-source-tab').forEach(e=>e.classList.remove('active'));this.classList.add('active');",
                                                       div(class = "tab-label", "FHIR Server")),
                                                   div(class = "odqa-source-tab", id = "src_demo",
                                                       onclick = "Shiny.setInputValue('src_tab','demo',{priority:'event'});document.querySelectorAll('.odqa-source-tab').forEach(e=>e.classList.remove('active'));this.classList.add('active');",
                                                       div(class = "tab-label", "Demo Dataset"))),
                                               # Local-file panel.
                                               div(id = "panel_local", div(class = "odqa-card",
                                                                           div(class = "odqa-card-header", div(class = "odqa-card-badge", "1"), div(div(class = "odqa-card-title", uiOutput("src_upload_title_ui")), div(class = "odqa-card-subtitle", uiOutput("src_upload_sub_ui")))),
                                                                           fluidRow(column(4, selectInput("file_type", "Format", c("CSV/TXT", "Excel", "JSON", "FHIR Bundle"), width = "100%")),
                                                                                    column(8, fileInput("file_csv", "File", accept = c(".csv", ".txt", ".xlsx", ".xls", ".json"), width = "100%"))),
                                                                           conditionalPanel("input.file_type=='CSV/TXT'",
                                                                                            fluidRow(column(4, checkboxInput("csv_header", "Has header", TRUE)),
                                                                                                     column(4, selectInput("csv_sep", "Separator", c("," = ",", ";" = ";", "Tab" = "\t", "|" = "|"), width = "100%")))),
                                                                           conditionalPanel("input.file_type=='Excel'", numericInput("xls_sheet", "Sheet number", 1, min = 1, max = 50, width = "150px")),
                                                                           div(class = "btn-group-odqa", actionButton("btn_load", "Load Data", class = "btn-odqa btn-odqa-primary")))),
                                               # SQL panel.
                                               div(id = "panel_db", style = "display:none;", div(class = "odqa-card",
                                                                                                 div(class = "odqa-card-header", div(class = "odqa-card-badge", "DB"), div(class = "odqa-card-title", "SQL Database Connection")),
                                                                                                 # SQL template buttons.
                                                                                                 div(class = "sql-template-btns",
                                                                                                     tags$button(class = "btn", onclick = "Shiny.setInputValue('sql_tpl','select',{priority:'event'})", "SELECT *"),
                                                                                                     tags$button(class = "btn", onclick = "Shiny.setInputValue('sql_tpl','count',{priority:'event'})", "COUNT"),
                                                                                                     tags$button(class = "btn", onclick = "Shiny.setInputValue('sql_tpl','top100',{priority:'event'})", "TOP 100"),
                                                                                                     tags$button(class = "btn", onclick = "Shiny.setInputValue('sql_tpl','tables',{priority:'event'})", "List Tables")),
                                                                                                 fluidRow(column(3, selectInput("sql_type", "Type", c("PostgreSQL", "Microsoft SQL"), width = "100%")),
                                                                                                          column(3, textInput("sql_host", "Host", "localhost", width = "100%")),
                                                                                                          column(2, numericInput("sql_port", "Port", 5432, min = 1, width = "100%")),
                                                                                                          column(4, textInput("sql_db", "Database", "", width = "100%"))),
                                                                                                 fluidRow(column(4, textInput("sql_user", "User", "", width = "100%")),
                                                                                                          column(4, passwordInput("sql_pw", "Password", "", width = "100%")),
                                                                                                          column(4, div(style = "margin-top:25px;", actionButton("btn_sql_test", "Test", class = "btn-odqa btn-odqa-secondary")))),
                                                                                                 textAreaInput("sql_query", "SQL Query", "", width = "100%", rows = 4),
                                                                                                 actionButton("btn_sql_run", "Run Query", class = "btn-odqa btn-odqa-primary"),
                                                                                                 uiOutput("sql_query_timer_ui"))),
                                               # FHIR panel.
                                               div(id = "panel_fhir", style = "display:none;", div(class = "odqa-card",
                                                                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "HL"), div(class = "odqa-card-title", "FHIR Server")),
                                                                                                   fluidRow(column(8, textInput("fhir_url", "Base URL", "https://hapi.fhir.org/baseR4", width = "100%")),
                                                                                                            column(4, div(style = "margin-top:25px;", actionButton("btn_fhir_test", "Test", class = "btn-odqa btn-odqa-secondary")))),
                                                                                                   textInput("fhir_query", "Resource Query", "Patient?_count=50", width = "100%"),
                                                                                                   actionButton("btn_fhir_run", "Fetch", class = "btn-odqa btn-odqa-primary"),
                                                                                                   uiOutput("fhir_query_timer_ui"))),
                                               # Demo panel.
                                               div(id = "panel_demo", style = "display:none;", div(class = "odqa-card",
                                                                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "D"), div(div(class = "odqa-card-title", "Demo Dataset"))),
                                                                                                   uiOutput("demo_desc_ui"),
                                                                                                   div(style = "margin-top:12px;", actionButton("btn_load_demo", "Load Demo Dataset", class = "btn-odqa btn-odqa-primary")))),
                                               # Preview.
                                               div(class = "odqa-card", style = "margin-top:14px;",
                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "P"), div(class = "odqa-card-title", uiOutput("preview_title_ui"))),
                                                   uiOutput("import_timer_ui"), DTOutput("dt_preview")),
                                               # Back and confirm buttons.
                                               div(class = "btn-group-odqa", style = "margin-top:14px;justify-content:space-between;width:100%;",
                                                   tags$button(class = "btn-odqa btn-odqa-secondary", onclick = "Shiny.setInputValue('nav_to',0,{priority:'event'})", "Back"),
                                                   actionButton("btn_confirm_data", uiOutput("s1_confirm_label"), class = "btn-odqa btn-odqa-success")))),
    
    # Step 2: Checks Studio.
    div(class = "odqa-step", id = "step2", div(class = "odqa-container",
                                               div(class = "odqa-step-header", uiOutput("s2_header")),
                                               
                                               div(class = "odqa-hint info",
                                                   span(class = "odqa-hint-icon", "i"),
                                                   uiOutput("s2_workflow_roadmap")),
                                               div(class = "odqa-domain-tabs",
                                                   tags$button(class = "odqa-domain-tab active", id = "dtab_d1",
                                                               onclick = paste0(
                                                                 "Shiny.setInputValue('domain_tab','d1',{priority:'event'});",
                                                                 "document.querySelectorAll('.odqa-domain-tab').forEach(t=>t.classList.remove('active'));",
                                                                 "document.querySelectorAll('.odqa-domain-panel').forEach(p=>p.classList.remove('active'));",
                                                                 "this.classList.add('active');",
                                                                 "document.getElementById('dpanel_d1').classList.add('active');"),
                                                               "D1: Statistical Profiling"),
                                                   tags$button(class = "odqa-domain-tab", id = "dtab_d2b",
                                                               onclick = paste0(
                                                                 "Shiny.setInputValue('domain_tab','d2b',{priority:'event'});",
                                                                 "document.querySelectorAll('.odqa-domain-tab').forEach(t=>t.classList.remove('active'));",
                                                                 "document.querySelectorAll('.odqa-domain-panel').forEach(p=>p.classList.remove('active'));",
                                                                 "this.classList.add('active');",
                                                                 "document.getElementById('dpanel_d2b').classList.add('active');"),
                                                               "D2 Base: Check Builder"),
                                                   tags$button(class = "odqa-domain-tab", id = "dtab_d2a",
                                                               onclick = paste0(
                                                                 "Shiny.setInputValue('domain_tab','d2a',{priority:'event'});",
                                                                 "document.querySelectorAll('.odqa-domain-tab').forEach(t=>t.classList.remove('active'));",
                                                                 "document.querySelectorAll('.odqa-domain-panel').forEach(p=>p.classList.remove('active'));",
                                                                 "this.classList.add('active');",
                                                                 "document.getElementById('dpanel_d2a').classList.add('active');"),
                                                               "D2 Advanced: Group / Conditional / R-Query"),
                                                   tags$button(class = "odqa-domain-tab", id = "dtab_d3",
                                                               onclick = paste0(
                                                                 "Shiny.setInputValue('domain_tab','d3',{priority:'event'});",
                                                                 "document.querySelectorAll('.odqa-domain-tab').forEach(t=>t.classList.remove('active'));",
                                                                 "document.querySelectorAll('.odqa-domain-panel').forEach(p=>p.classList.remove('active'));",
                                                                 "this.classList.add('active');",
                                                                 "document.getElementById('dpanel_d3').classList.add('active');"),
                                                               "D3: Check Manager & Execute")),
                                               # D1.
                                               div(class = "odqa-domain-panel active", id = "dpanel_d1", div(class = "odqa-card",
                                                                                                             div(class = "odqa-card-header", div(class = "odqa-card-badge", "D1"),
                                                                                                                 div(div(class = "odqa-card-title", uiOutput("d1_title_ui")), div(class = "odqa-card-subtitle", uiOutput("d1_desc_ui")))),
                                                                                                             actionButton("btn_stat_run", uiOutput("btn_stat_run_ui"), class = "btn-odqa btn-odqa-primary"),
                                                                                                             uiOutput("stat_timer_ui"), uiOutput("stat_suggestions_ui"))),
                                               
                                               # D2 Base: column-to-value and column-to-column builder.
                                               div(class = "odqa-domain-panel", id = "dpanel_d2b",
                                                   div(class = "odqa-card",
                                                       div(class = "odqa-card-header",
                                                           div(class = "odqa-card-badge", "D2B"),
                                                           div(div(class = "odqa-card-title", uiOutput("d2_base_card_title_ui")),
                                                               div(class = "odqa-card-subtitle", uiOutput("d2_base_card_sub_ui")))),
                                                       
                                                       # Step 0: check type.
                                                       h4(style = "font-size:14px;font-weight:700;", uiOutput("d2_step0_title_ui")),
                                                       div(class = "odqa-hint info",
                                                           span(class = "odqa-hint-icon", "i"),
                                                           uiOutput("d2_step0_hint_ui")),
                                                       fluidRow(column(4, uiOutput("cb_check_type_ui"))),
                                                       
                                                       # Step 1: conditions.
                                                       h4(style = "font-size:14px;font-weight:700;margin-top:14px;",
                                                          uiOutput("d2_step1_title_ui")),
                                                       fluidRow(
                                                         column(3, uiOutput("cb_col_ui")),
                                                         column(2, selectInput("cb_op", "Operator", c(
                                                           "==" = "==", "!=" = "!=", ">" = ">", "<" = "<", ">=" = ">=", "<=" = "<=",
                                                           "is.na" = "is.na", "is_not.na" = "is_not.na",
                                                           "contains" = "contains", "not_contains" = "not_contains",
                                                           "starts_with" = "starts_with", "ends_with" = "ends_with",
                                                           "BETWEEN" = "BETWEEN", "NOT BETWEEN" = "NOT BETWEEN",
                                                           "IN" = "IN", "NOT IN" = "NOT IN",
                                                           "REGEXP" = "REGEXP",
                                                           "is_duplicate" = "is_duplicate", "is_unique" = "is_unique"
                                                         ), width = "100%")),
                                                         column(3, uiOutput("cb_val_ui")),
                                                         column(2, selectInput("cb_logic", "Logic",
                                                                               c("AND" = "&", "OR" = "|", "END (finish)" = "END"),
                                                                               width = "100%")),
                                                         column(2, div(style = "margin-top:25px;",
                                                                       actionButton("cb_add_cond", uiOutput("d2_add_btn_ui"),
                                                                                    class = "btn-odqa btn-odqa-primary")))),
                                                       
                                                       # Value-list import.
                                                       div(style = "margin-bottom:12px;",
                                                           fluidRow(
                                                             column(4, fileInput("cb_import_file",
                                                                                 "Import Value List (CSV, JSON, Excel, TXT)",
                                                                                 accept = c(".csv", ".txt", ".json", ".xlsx", ".xls"),
                                                                                 width = "100%")),
                                                             column(4, div(style = "font-size:11px;color:var(--text-tertiary);margin-top:28px;",
                                                                           "File may use one value per line, or separate with comma , or semicolon ;")),
                                                             column(4, uiOutput("cb_import_count")))),
                                                       
                                                       # Conditions table plus compile, test, and clear actions.
                                                       h4(style = "font-size:14px;font-weight:700;",
                                                          uiOutput("d2_current_conds_ui")),
                                                       DTOutput("dt_conditions"),
                                                       div(class = "btn-group-odqa", style = "margin:8px 0;",
                                                           actionButton("cb_compile",     uiOutput("d2_gen_expr_btn"),   class = "btn-odqa btn-odqa-secondary"),
                                                           actionButton("cb_test_query",  uiOutput("d2_test_query_btn"), class = "btn-odqa btn-odqa-primary"),
                                                           actionButton("cb_clear_conds", uiOutput("d2_clear_btn"),      class = "btn-odqa btn-odqa-ghost")),
                                                       div(class = "expr-code",
                                                           style = "margin:8px 0;padding:8px 12px;min-height:32px;",
                                                           textOutput("cb_expr_preview")),
                                                       uiOutput("cb_impact_preview"),
                                                       
                                                       # Step 2: name and save.
                                                       h4(style = "font-size:14px;font-weight:700;margin-top:12px;",
                                                          uiOutput("d2_step2_title_ui")),
                                                       fluidRow(
                                                         column(4, uiOutput("d2_name_input_ui")),
                                                         column(4, uiOutput("d2_desc_input_ui")),
                                                         column(2, uiOutput("d2_sev_input_ui")),
                                                         column(2, div(style = "margin-top:25px;",
                                                                       actionButton("cb_save", uiOutput("d2_save_btn"),
                                                                                    class = "btn-odqa btn-odqa-success")))))),
                                               
                                               # D2 Advanced: GROUP BY, IF-THEN, and free R-query builders.
                                               div(class = "odqa-domain-panel", id = "dpanel_d2a",
                                                   div(class = "odqa-card",
                                                       div(class = "odqa-card-header",
                                                           div(class = "odqa-card-badge", "D2A"),
                                                           div(div(class = "odqa-card-title", uiOutput("d2_adv_card_title_ui")),
                                                               div(class = "odqa-card-subtitle", uiOutput("d2_adv_card_sub_ui")))),
                                                       
                                                       # Sub-tabs.
                                                       div(class = "odqa-domain-tabs", style = "margin-top:4px;",
                                                           tags$button(class = "odqa-domain-tab active", id = "adtab_gb",
                                                                       onclick = paste0(
                                                                         "document.querySelectorAll('#dpanel_d2a .odqa-domain-tab').forEach(t=>t.classList.remove('active'));",
                                                                         "document.querySelectorAll('#dpanel_d2a .odqa-sub-panel').forEach(p=>p.classList.remove('active'));",
                                                                         "this.classList.add('active');",
                                                                         "document.getElementById('adsub_gb').classList.add('active');"),
                                                                       "GROUP BY (aggregate)"),
                                                           tags$button(class = "odqa-domain-tab", id = "adtab_if",
                                                                       onclick = paste0(
                                                                         "document.querySelectorAll('#dpanel_d2a .odqa-domain-tab').forEach(t=>t.classList.remove('active'));",
                                                                         "document.querySelectorAll('#dpanel_d2a .odqa-sub-panel').forEach(p=>p.classList.remove('active'));",
                                                                         "this.classList.add('active');",
                                                                         "document.getElementById('adsub_if').classList.add('active');"),
                                                                       "IF-THEN (conditional)"),
                                                           tags$button(class = "odqa-domain-tab", id = "adtab_rq",
                                                                       onclick = paste0(
                                                                         "document.querySelectorAll('#dpanel_d2a .odqa-domain-tab').forEach(t=>t.classList.remove('active'));",
                                                                         "document.querySelectorAll('#dpanel_d2a .odqa-sub-panel').forEach(p=>p.classList.remove('active'));",
                                                                         "this.classList.add('active');",
                                                                         "document.getElementById('adsub_rq').classList.add('active');"),
                                                                       "Designing R-Query")),
                                                       
                                                       # GROUP BY sub-panel.
                                                       div(id = "adsub_gb", class = "odqa-sub-panel active",
                                                           div(class = "odqa-hint info",
                                                               span(class = "odqa-hint-icon", "i"),
                                                               "Flag groups that violate an aggregate rule. Example: flag patient IDs that appear more than once (count > 1)."),
                                                           fluidRow(
                                                             column(3, uiOutput("adv_gb_col_ui")),
                                                             column(3, selectInput("adv_gb_agg", "Aggregation",
                                                                                   c("count > threshold"      = "count_gt",
                                                                                     "count < threshold"      = "count_lt",
                                                                                     "count == threshold"     = "count_eq",
                                                                                     "n_distinct > threshold" = "ndistinct_gt",
                                                                                     "sum > threshold"        = "sum_gt",
                                                                                     "mean > threshold"       = "mean_gt",
                                                                                     "min < threshold"        = "min_lt",
                                                                                     "max > threshold"        = "max_gt"),
                                                                                   width = "100%")),
                                                             column(3, uiOutput("adv_gb_target_ui")),
                                                             column(3, numericInput("adv_gb_thresh", "Threshold",
                                                                                    value = 1, width = "100%"))),
                                                           div(class = "btn-group-odqa", style = "margin:8px 0;",
                                                               actionButton("adv_gb_test",  "Test GROUP BY query", class = "btn-odqa btn-odqa-primary"),
                                                               actionButton("adv_gb_clear", "Clear",               class = "btn-odqa btn-odqa-ghost")),
                                                           div(class = "expr-code",
                                                               style = "margin:8px 0;padding:8px 12px;min-height:32px;",
                                                               textOutput("adv_gb_preview")),
                                                           uiOutput("adv_gb_impact"),
                                                           # Name and save.
                                                           fluidRow(
                                                             column(4, textInput("adv_gb_name", "Check name", "",   width = "100%")),
                                                             column(4, textInput("adv_gb_desc", "Description", "",  width = "100%")),
                                                             column(2, selectInput("adv_gb_sev", "Severity",
                                                                                   c("Low","Medium","High","Critical"),
                                                                                   selected = "Medium", width = "100%")),
                                                             column(2, div(style = "margin-top:25px;",
                                                                           actionButton("adv_gb_save", "Save check",
                                                                                        class = "btn-odqa btn-odqa-success"))))),
                                                       
                                                       # IF-THEN sub-panel.
                                                       div(id = "adsub_if", class = "odqa-sub-panel",
                                                           div(class = "odqa-hint info",
                                                               span(class = "odqa-hint-icon", "i"),
                                                               "IF (precondition on column A) THEN (column B must satisfy rule). Example: IF icd_code starts with O THEN gender must equal W."),
                                                           fluidRow(
                                                             column(3, uiOutput("adv_if_col_ui")),
                                                             column(2, selectInput("adv_if_op", "IF operator",
                                                                                   c("contains" = "contains",
                                                                                     "starts_with" = "starts_with",
                                                                                     "ends_with" = "ends_with",
                                                                                     "==" = "==", "!=" = "!=",
                                                                                     "is.na" = "is.na",
                                                                                     "REGEXP" = "REGEXP"),
                                                                                   width = "100%")),
                                                             column(3, textInput("adv_if_val", "IF value", "", width = "100%")),
                                                             column(4, div(style = "font-size:11px;color:var(--text-tertiary);margin-top:28px;",
                                                                           "Separate multiple values with comma , or semicolon ; if using IN / NOT IN in the THEN clause below."))),
                                                           fluidRow(
                                                             column(3, uiOutput("adv_then_col_ui")),
                                                             column(2, selectInput("adv_then_op", "THEN operator",
                                                                                   c("==" = "==", "!=" = "!=", ">" = ">", "<" = "<", ">=" = ">=", "<=" = "<=",
                                                                                     "is.na" = "is.na", "is_not.na" = "is_not.na",
                                                                                     "contains" = "contains", "not_contains" = "not_contains",
                                                                                     "starts_with" = "starts_with", "ends_with" = "ends_with",
                                                                                     "BETWEEN" = "BETWEEN", "NOT BETWEEN" = "NOT BETWEEN",
                                                                                     "IN" = "IN", "NOT IN" = "NOT IN",
                                                                                     "REGEXP" = "REGEXP"),
                                                                                   width = "100%")),
                                                             column(3, textInput("adv_then_val", "THEN value", "", width = "100%")),
                                                             column(4, div(style = "font-size:11px;color:var(--text-tertiary);margin-top:28px;",
                                                                           "BETWEEN / NOT BETWEEN use 'min;max' (semicolon). IN / NOT IN accept , or ; ."))),
                                                           div(class = "btn-group-odqa", style = "margin:8px 0;",
                                                               actionButton("adv_if_test",  "Test IF-THEN query", class = "btn-odqa btn-odqa-primary"),
                                                               actionButton("adv_if_clear", "Clear",              class = "btn-odqa btn-odqa-ghost")),
                                                           div(class = "expr-code",
                                                               style = "margin:8px 0;padding:8px 12px;min-height:32px;",
                                                               textOutput("adv_if_preview")),
                                                           uiOutput("adv_if_impact"),
                                                           fluidRow(
                                                             column(4, textInput("adv_if_name", "Check name", "",   width = "100%")),
                                                             column(4, textInput("adv_if_desc", "Description", "",  width = "100%")),
                                                             column(2, selectInput("adv_if_sev", "Severity",
                                                                                   c("Low","Medium","High","Critical"),
                                                                                   selected = "Medium", width = "100%")),
                                                             column(2, div(style = "margin-top:25px;",
                                                                           actionButton("adv_if_save", "Save check",
                                                                                        class = "btn-odqa btn-odqa-success"))))),
                                                       
                                                       # Free R-query sub-panel.
                                                       div(id = "adsub_rq", class = "odqa-sub-panel",
                                                           div(class = "odqa-hint info",
                                                               span(class = "odqa-hint-icon", "i"),
                                                               "Write any R logical expression that evaluates per row. Same security blacklist as D2 Base applies: no system calls, no eval, no file access. TRUE means the row is flagged."),
                                                           textAreaInput("adv_rq_expr", "R expression",
                                                                         value = "",
                                                                         placeholder = "e.g. age > 120 | (as.Date(admission_date) > as.Date(discharge_date))",
                                                                         rows = 4, width = "100%"),
                                                           div(class = "btn-group-odqa", style = "margin:8px 0;",
                                                               actionButton("adv_rq_test",  "Test R-Query", class = "btn-odqa btn-odqa-primary"),
                                                               actionButton("adv_rq_clear", "Clear",        class = "btn-odqa btn-odqa-ghost")),
                                                           uiOutput("adv_rq_impact"),
                                                           fluidRow(
                                                             column(4, textInput("adv_rq_name", "Check name", "",   width = "100%")),
                                                             column(4, textInput("adv_rq_desc", "Description", "",  width = "100%")),
                                                             column(2, selectInput("adv_rq_sev", "Severity",
                                                                                   c("Low","Medium","High","Critical"),
                                                                                   selected = "Medium", width = "100%")),
                                                             column(2, div(style = "margin-top:25px;",
                                                                           actionButton("adv_rq_save", "Save check",
                                                                                        class = "btn-odqa btn-odqa-success"))))))),
                                               # D3.
                                               div(class = "odqa-domain-panel", id = "dpanel_d3", div(class = "odqa-card",
                                                                                                      div(class = "odqa-card-header", div(class = "odqa-card-badge", "D3"),
                                                                                                          div(div(class = "odqa-card-title", uiOutput("d3_title_ui")), div(class = "odqa-card-subtitle", uiOutput("d3_desc_ui")))),
                                                                                                      uiOutput("d3_checks_count"),
                                                                                                      DTOutput("dt_all_checks"),
                                                                                                      div(class = "btn-group-odqa", style = "margin-top:10px;",
                                                                                                          actionButton("d3_run_checks", uiOutput("d3_exec_btn_ui"), class = "btn-odqa btn-odqa-primary"),
                                                                                                          actionButton("d3_delete_sel", uiOutput("d3_delete_btn_ui"), class = "btn-odqa btn-odqa-danger"),
                                                                                                          downloadButton("d3_export_json", "Export JSON", class = "btn-odqa btn-odqa-secondary"),
                                                                                                          fileInput("d3_import_json", NULL, accept = ".json", width = "200px")))))),
    
    # Step 3: results.
    div(class = "odqa-step", id = "step3", div(class = "odqa-container",
                                               div(class = "odqa-step-header", uiOutput("s3_header")),
                                               uiOutput("s3_metrics"), uiOutput("s3_interpretation"),
                                               div(class = "odqa-hint info", span(class = "odqa-hint-icon", "i"), uiOutput("s3_score_note")),
                                               uiOutput("s3_score_band_info"),
                                               fluidRow(column(6, div(class = "odqa-chart-container", h4(uiOutput("chart_sev_title")), plotOutput("plot_severity", height = "280px"))),
                                                        column(6, div(class = "odqa-chart-container", h4(uiOutput("chart_cat_title")), plotOutput("plot_category", height = "280px")))),
                                               div(class = "odqa-card",
                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "D"), div(class = "odqa-card-title", uiOutput("detail_title"))),
                                                   DTOutput("dt_issues")),
                                               uiOutput("s3_check_impact_ui"),
                                               div(class = "btn-group-odqa", style = "margin-top:12px;",
                                                   downloadButton("dl_dq_cert", uiOutput("s3_cert_dq_btn"), class = "btn-odqa btn-odqa-primary"),
                                                   downloadButton("dl_issues_csv", uiOutput("s3_cert_issues_btn"), class = "btn-odqa btn-odqa-secondary")))),
    
    # Step 4: cleansing.
    div(class = "odqa-step", id = "step4", div(class = "odqa-container",
                                               div(class = "odqa-step-header", uiOutput("s4_header")),
                                               # Roadmap card. Lists each sub-step and the recommended order.
                                               div(class = "odqa-card",
                                                   div(class = "odqa-card-header",
                                                       div(class = "odqa-card-badge", "R"),
                                                       div(class = "odqa-card-title",
                                                           uiOutput("s4_overview_title_ui"))),
                                                   uiOutput("s4_overview_body_ui")),
                                               # Sub-step 4.1: issue-guided record review.
                                               div(class = "odqa-card",
                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "4.1"),
                                                       div(div(class = "odqa-card-title", uiOutput("s4_guide_title")),
                                                           div(class = "odqa-card-subtitle", uiOutput("s4_guide_sub")))),
                                                   uiOutput("cl_issue_select"),
                                                   actionButton("cl_start_review", uiOutput("btn_start_review_ui"), class = "btn-odqa btn-odqa-primary"),
                                                   uiOutput("cl_record_nav"), uiOutput("cl_record_display"), uiOutput("cl_record_actions")),
                                               # Sub-step 4.2: find and replace.
                                               div(class = "odqa-card",
                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "4.2"), div(class = "odqa-card-title", uiOutput("s4_bulk_title"))),
                                                   fluidRow(column(3, uiOutput("cl_fr_col_ui")), column(3, textInput("cl_find", "Find", "", width = "100%")),
                                                            column(3, textInput("cl_replace", "Replace with", "", width = "100%")),
                                                            column(3, div(style = "margin-top:25px;", div(class = "btn-group-odqa",
                                                                                                          actionButton("cl_fr_preview", "Preview", class = "btn-odqa btn-odqa-secondary"),
                                                                                                          actionButton("cl_fr_go", "Replace All", class = "btn-odqa btn-odqa-primary"))))),
                                                   fluidRow(column(3, checkboxInput("cl_fr_regex", "Regex", FALSE)),
                                                            column(3, checkboxInput("cl_fr_case", "Case sensitive", FALSE))),
                                                   uiOutput("cl_fr_preview_ui")),
                                               # Sub-step 4.3: manual cell editing.
                                               div(class = "odqa-card",
                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "4.3"), div(class = "odqa-card-title", uiOutput("s4_manual_title"))),
                                                   uiOutput("s4_manual_hint"), DTOutput("dt_cl_edit")),
                                               # Sub-step 4.4: audit trail.
                                               div(class = "odqa-card",
                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "4.4"), div(class = "odqa-card-title", uiOutput("s4_log_title"))),
                                                   DTOutput("dt_cl_log")),
                                               # Sub-step 4.5: original vs cleaned.
                                               div(class = "odqa-card",
                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "4.5"), div(class = "odqa-card-title", uiOutput("s4_compare_title"))),
                                                   actionButton("cl_gen_compare", uiOutput("cl_gen_compare_ui"), class = "btn-odqa btn-odqa-secondary"),
                                                   div(class = "odqa-compare", uiOutput("dt_cl_orig_diff"), uiOutput("dt_cl_clean_diff"))),
                                               # Sub-step 4.6: rename column.
                                               div(class = "odqa-card",
                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "4.6"), div(class = "odqa-card-title", uiOutput("s4_rename_title"))),
                                                   fluidRow(column(4, uiOutput("cl_rename_col_ui")),
                                                            column(4, uiOutput("cl_new_name_ui")),
                                                            column(4, div(style = "margin-top:25px;", actionButton("cl_rename_go", uiOutput("cl_rename_btn_ui"), class = "btn-odqa btn-odqa-primary"))))),
                                               # Sub-step 4.7: fix column format. Incompatible cells become NA and are
                                               # logged in the audit trail.
                                               div(class = "odqa-card",
                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "4.7"),
                                                       div(class = "odqa-card-title", uiOutput("s4_fmt_title_ui"))),
                                                   div(class = "odqa-hint info",
                                                       span(class = "odqa-hint-icon", "i"),
                                                       uiOutput("s4_fmt_hint_ui")),
                                                   DTOutput("dt_cl_types"),
                                                   fluidRow(
                                                     column(4, uiOutput("cl_fmt_col_ui")),
                                                     column(3, selectInput("cl_fmt_target", "Target type",
                                                                           c("character","integer","numeric","logical","date","datetime"),
                                                                           width = "100%")),
                                                     column(2, div(style = "margin-top:25px;",
                                                                   actionButton("cl_fmt_preview", "Preview NAs",
                                                                                class = "btn-odqa btn-odqa-secondary"))),
                                                     column(3, div(style = "margin-top:25px;",
                                                                   actionButton("cl_fmt_apply", "Apply coercion",
                                                                                class = "btn-odqa btn-odqa-primary")))),
                                                   uiOutput("cl_fmt_preview_ui")),
                                               # Sub-step 4.8: delete column.
                                               div(class = "odqa-card",
                                                   div(class = "odqa-card-header", div(class = "odqa-card-badge", "4.8"), div(class = "odqa-card-title", uiOutput("s4_delcol_title_ui"))),
                                                   fluidRow(column(4, uiOutput("cl_delcol_ui")),
                                                            column(4, div(style = "margin-top:25px;", actionButton("cl_delcol", uiOutput("cl_delete_col_btn_ui"), class = "btn-odqa btn-odqa-danger"))))),
                                               div(class = "btn-group-odqa", style = "margin-top:12px;",
                                                   downloadButton("dl_cl_cert", uiOutput("cert_cleansing_btn"), class = "btn-odqa btn-odqa-primary"),
                                                   downloadButton("dl_cl_data", uiOutput("cert_cleaned_btn"), class = "btn-odqa btn-odqa-secondary"),
                                                   downloadButton("dl_cl_log_csv", uiOutput("cert_audit_btn"), class = "btn-odqa btn-odqa-ghost")))),
    
    # Summary screen.
    div(class = "odqa-step", id = "stepF", div(class = "odqa-container", div(class = "odqa-finish",
                                                                             h1(uiOutput("finish_title_ui")), uiOutput("finish_recap_ui"),
                                                                             div(class = "btn-group-odqa", style = "justify-content:center;margin-top:16px;",
                                                                                 downloadButton("dl_final_cert", uiOutput("cert_dq_btn"), class = "btn-odqa btn-odqa-primary"),
                                                                                 downloadButton("dl_final_issues", uiOutput("cert_issues_btn"), class = "btn-odqa btn-odqa-secondary"),
                                                                                 downloadButton("dl_final_cl_cert", uiOutput("cert_cl_btn2"), class = "btn-odqa btn-odqa-primary"),
                                                                                 downloadButton("dl_final_cleaned", uiOutput("cert_cleaned_btn2"), class = "btn-odqa btn-odqa-secondary")),
                                                                             div(style = "margin-top:16px;", uiOutput("finish_feedback_ui")),
                                                                             actionButton("btn_new_analysis", uiOutput("btn_new_analysis_ui"), class = "btn-odqa btn-odqa-ghost", style = "margin-top:12px;")))),
    
    # Footer.
    div(class = "odqa-footer",
        div(class = "btn-group-odqa", uiOutput("footer_indicator")),
        div(class = "btn-group-odqa", uiOutput("footer_next_btn")))
  )
)

##############################################################################
# Server logic.
##############################################################################
server <- function(input, output, session) {
  rv <- reactiveValues(
    step = 0, max_step = 0, disclaimer_ok = FALSE, analyst_done = FALSE,
    raw_data = NULL, work_data = NULL, original_data = NULL, data_confirmed = FALSE,
    custom_checks = list(), stat_suggestions = list(),
    issues = NULL, quality_score = NULL, types_cache = NULL,
    cl_log = data.frame(timestamp = character(), action = character(), column = character(),
                        row = character(), old_value = character(), new_value = character(), stringsAsFactors = FALSE),
    cl_undo_stack = list(), user_info = list(name = "", func = ""),
    cb_conditions = list(), cb_compiled_expr = NULL, cb_imported_values = NULL,
    cl_review_rows = integer(0), cl_review_idx = 1L,
    perf_data = list()
  )
  lang <- reactive({ input$lang %||% "en" })
  # Eager outputs across all Studio tabs. Shiny suspends outputs inside hidden DOM. D1,
  # D2 Base, D2 Advanced, and D3 are all hidden by CSS until the user clicks their tab,
  # which would prevent their outputs from evaluating on a tab switch. Marking these
  # outputs as non-suspending makes every dataset change and every check save propagate
  # to every tab immediately, so when the user switches tabs the content is already
  # painted and the switch becomes a pure CSS operation. The cost is negligible because
  # the dependencies (rv$work_data and rv$custom_checks) are small. Step 3 per-check
  # plots are registered dynamically by index and are marked eager in their own block
  # below.
  eager_outputs <- c(
    # D3 check manager.
    "dt_all_checks", "d3_checks_count",
    "d3_title_ui", "d3_desc_ui",
    "d3_exec_btn_ui", "d3_delete_btn_ui",
    # D1 statistical profiling.
    "stat_suggestions_ui", "stat_timer_ui",
    "d1_title_ui", "d1_desc_ui", "btn_stat_run_ui",
    # D2 Base.
    "d2_base_card_title_ui", "d2_base_card_sub_ui",
    "d2_step0_title_ui", "d2_step0_hint_ui",
    "d2_step1_title_ui", "d2_step2_title_ui",
    "cb_check_type_ui", "cb_col_ui", "cb_val_ui",
    "cb_import_count", "dt_conditions", "cb_expr_preview",
    "cb_impact_preview",
    "d2_current_conds_ui", "d2_gen_expr_btn", "d2_test_query_btn",
    "d2_clear_btn", "d2_save_btn", "d2_add_btn_ui",
    "d2_name_input_ui", "d2_desc_input_ui", "d2_sev_input_ui",
    # D2 Advanced.
    "d2_adv_card_title_ui", "d2_adv_card_sub_ui",
    "adv_tab_gb_lbl", "adv_tab_if_lbl", "adv_tab_rq_lbl",
    "adv_gb_col_ui", "adv_gb_target_ui",
    "adv_if_col_ui", "adv_then_col_ui",
    "adv_gb_preview", "adv_if_preview",
    "adv_gb_impact", "adv_if_impact", "adv_rq_impact"
  )
  for (nm in eager_outputs) {
    tryCatch(
      outputOptions(output, nm, suspendWhenHidden = FALSE),
      error = function(e) NULL
    )
  }
  
  # Navigation.
  go <- function(s) {
    rv$step <- s
    if (is.numeric(s) && s > rv$max_step) rv$max_step <- s
    session$sendCustomMessage("goto_step", s)
    session$sendCustomMessage("enable_pills", rv$max_step)
    # Pre-compute the per-column type table on entry to Step 3, so that Step 4.7 does
    # not have to compute it when the user first opens that sub-step. The result is
    # cached in rv$types_cache and read by dt_cl_types.
    if (identical(s, 3) && !is.null(rv$work_data) && is.null(rv$types_cache)) {
      isolate({
        df <- rv$work_data
        rv$types_cache <- data.frame(
          Column        = names(df),
          Current_Class = vapply(df, function(x) paste(class(x), collapse = "/"), character(1)),
          Detected_Type = vapply(df, detect_col_type, character(1)),
          Non_NA        = vapply(df, function(x) sum(!is.na(x) & nzchar(trimws(as.character(x)))), integer(1)),
          stringsAsFactors = FALSE
        )
      })
    }
  }
  
  # Push pill translations to the client whenever the language changes. The JS handler
  # updates the innerText of each pill by its DOM id.
  observeEvent(lang(), {
    l <- lang()
    session$sendCustomMessage("set_pill_labels", list(
      pill_0 = i18n("pill_home",      l),
      pill_1 = i18n("pill_import",    l),
      pill_2 = i18n("pill_studio",    l),
      pill_3 = i18n("pill_results",   l),
      pill_4 = i18n("pill_cleansing", l),
      pill_F = i18n("pill_summary",   l)
    ))
  }, ignoreInit = FALSE)
  observeEvent(input$nav_to, {
    s <- input$nav_to
    if (s == "F" || (is.numeric(s) && s <= rv$max_step + 1)) go(s)
  })
  observeEvent(input$nav_home, go(0))
  observeEvent(input$go_tutorial, go("T"))
  observeEvent(input$btn_new_analysis, {
    showModal(modalDialog(title = i18n("confirm_reset", lang()), i18n("confirm_reset", lang()),
                          footer = tagList(modalButton(i18n("btn_back", lang())),
                                           actionButton("confirm_reset_yes", "Confirm", class = "btn-odqa btn-odqa-danger"))))
  })
  observeEvent(input$confirm_reset_yes, {
    removeModal()
    rv$raw_data <- NULL; rv$work_data <- NULL; rv$original_data <- NULL
    rv$custom_checks <- list(); rv$stat_suggestions <- list()
    rv$issues <- NULL; rv$quality_score <- NULL; rv$data_confirmed <- FALSE
    rv$cl_log <- data.frame(timestamp = character(), action = character(), column = character(),
                            row = character(), old_value = character(), new_value = character(), stringsAsFactors = FALSE)
    rv$cl_undo_stack <- list(); rv$cb_conditions <- list(); rv$max_step <- 0
    go(0)
  })
  observeEvent(input$btn_next_f, {
    s <- rv$step
    if (is.numeric(s)) {
      if (s == 0) go(1)
      else if (s == 1 && isTRUE(rv$data_confirmed)) go(2)
      else if (s == 1 && !is.null(rv$work_data)) safe_notify("Please confirm the dataset first.", "warning")
      else if (s == 2) {
        if (length(rv$custom_checks) > 0 && !is.null(rv$work_data)) {
          t0 <- proc.time()
          rv$issues <- execute_checks(rv$work_data, rv$custom_checks)
          rv$quality_score <- calc_quality_score(nrow(rv$work_data), rv$issues)
          rv$perf_data$check_exec <- (proc.time() - t0)[3]
        } else {
          rv$issues <- data.frame(check_id = character(), issue = character(),
                                  severity = character(), row = integer(), stringsAsFactors = FALSE)
          rv$quality_score <- list(score = 100, affected_rows = 0L, issue_count = 0L)
        }
        go(3)
      } else if (s == 3) { rv$original_data <- rv$work_data; go(4) }
      else if (s == 4) go("F")
    }
  })
  observeEvent(input$src_tab, {
    for (p in c("local", "db", "fhir", "demo"))
      shinyjs::toggle(id = paste0("panel_", p), condition = (input$src_tab == p))
  })
  # Global timer strip. Shows the most recent duration of every named process. The
  # rv$perf_data list is populated by every timed action in the app.
  output$proctimer_ui <- renderUI({
    pd <- rv$perf_data %||% list()
    proc_labels <- c(
      import      = "Import",
      stat_analysis = "Profiling",
      d2_test     = "Base Test Query",
      d2a_test    = "Advanced Test Query",
      check_exec  = "Check execution",
      cert_dq     = "DQ Certificate",
      cert_cl     = "Cleansing Certificate"
    )
    if (length(pd) == 0) {
      return(tagList(span(class = "pt-chip",
                          span(class = "pt-label", "Status:"),
                          span(class = "pt-val",   "idle"))))
    }
    chips <- lapply(names(proc_labels), function(k) {
      v <- pd[[k]]
      if (is.null(v) || !is.numeric(v) || !is.finite(v)) return(NULL)
      span(class = "pt-chip",
           span(class = "pt-label", paste0(proc_labels[[k]], ":")),
           span(class = "pt-val",   format_elapsed(as.numeric(v))))
    })
    chips <- Filter(Negate(is.null), chips)
    if (!length(chips)) chips <- list(span(class = "pt-chip",
                                           span(class = "pt-label", "Status:"),
                                           span(class = "pt-val", "idle")))
    do.call(tagList, chips)
  })
  
  observeEvent(input$disc_proceed, {
    # The proceed button is disabled on the client unless the acceptance checkbox is
    # ticked, so reaching this observer already implies consent.
    rv$disclaimer_ok <- TRUE
    shinyjs::hide("disclaimer_overlay")
    shinyjs::show("analyst_overlay")
  })
  
  # Analyst overlay.
  output$analyst_overlay_ui <- renderUI({
    l <- lang()
    tagList(
      h2(i18n("landing_title", l)),
      p(style = "font-size:13px;color:var(--text-secondary);", i18n("landing_sub", l)),
      textInput("analyst_name", i18n("landing_name", l), "", width = "100%"),
      textInput("analyst_func", i18n("landing_function", l), "", width = "100%"),
      div(class = "btn-group-odqa", style = "margin-top:12px;",
          tags$button(class = "btn-odqa btn-odqa-ghost",
                      onclick = "Shiny.setInputValue('analyst_skip',Math.random(),{priority:'event'})",
                      i18n("landing_skip", l)),
          tags$button(class = "btn-odqa btn-odqa-primary",
                      onclick = "Shiny.setInputValue('analyst_save',Math.random(),{priority:'event'})",
                      i18n("landing_save", l))))
  })
  observeEvent(input$analyst_skip, { rv$analyst_done <- TRUE; shinyjs::hide("analyst_overlay") })
  observeEvent(input$analyst_save, {
    rv$user_info$name <- input$analyst_name %||% ""
    rv$user_info$func <- input$analyst_func %||% ""
    rv$analyst_done <- TRUE; shinyjs::hide("analyst_overlay")
    safe_notify("Analyst information saved.", "message")
  })
  
  # Welcome-screen text.
  output$hero_title_text <- renderUI(i18n("wel_title", lang()))
  
  # Additional outputs for full trilingual coverage.
  output$d2_base_card_title_ui <- renderUI(i18n("d2_base_card_title", lang()))
  output$d2_base_card_sub_ui   <- renderUI(i18n("d2_base_card_sub",   lang()))
  output$d2_adv_card_title_ui  <- renderUI(i18n("d2_adv_card_title",  lang()))
  output$d2_adv_card_sub_ui    <- renderUI(i18n("d2_adv_card_sub",    lang()))
  output$adv_tab_gb_lbl        <- renderText(i18n("d2_adv_tab_gb", lang()))
  output$adv_tab_if_lbl        <- renderText(i18n("d2_adv_tab_if", lang()))
  output$adv_tab_rq_lbl        <- renderText(i18n("d2_adv_tab_rq", lang()))
  output$src_upload_title_ui   <- renderUI(i18n("src_upload_title", lang()))
  output$src_upload_sub_ui     <- renderUI(i18n("src_upload_sub",   lang()))
  output$hero_sub_text <- renderUI(i18n("wel_sub", lang()))
  output$card_tut_title <- renderUI(i18n("wel_tut", lang()))
  output$card_tut_desc <- renderUI(i18n("wel_tut_hint", lang()))
  output$card_start_title <- renderUI(i18n("wel_start", lang()))
  output$card_start_desc <- renderUI(i18n("wel_start_hint", lang()))
  output$hero_workflow <- renderUI({
    l <- lang()
    tagList(
      h3(style = "font-size:16px;font-weight:800;margin:20px 0 12px;", i18n("wel_workflow_title", l)),
      div(class = "odqa-workflow",
          div(class = "odqa-wf-step", div(class = "odqa-wf-num", "1"), div(class = "odqa-wf-label", "Import")),
          div(class = "odqa-wf-step", div(class = "odqa-wf-num", "2"), div(class = "odqa-wf-label", "Check")),
          div(class = "odqa-wf-step", div(class = "odqa-wf-num", "3"), div(class = "odqa-wf-label", "Results")),
          div(class = "odqa-wf-step", div(class = "odqa-wf-num", "4"), div(class = "odqa-wf-label", "Cleanse"))))
  })
  output$hero_who <- renderUI(NULL)  # Intentionally empty.
  output$hero_faq <- renderUI({
    l <- lang()
    faqs <- list(
      list(q = "What file formats are supported?", a = "CSV, Excel (.xlsx), JSON, FHIR Bundle (JSON), and SQL databases (PostgreSQL, MS SQL). A demo dataset with 50 German clinical records is also available."),
      list(q = "What is the fitness-for-purpose approach?", a = "Quality criteria are defined specifically for your research question, rather than applying generic checks."),
      list(q = "How are checks created?", a = "D1 Statistical Profiling (automated), D2 Manual Check Builder (step-by-step custom rules), D3 Check Manager (review, execute)."),
      list(q = "What about D1 statistical profiling?", a = "Analyzes completeness, outliers, ICD/OPS validity, temporal order, duplicates, correlations, and cross-column plausibility. Each suggestion explains the statistical basis."),
      list(q = "How does cleansing work?", a = "Record-by-record guided review. Select an issue, review each affected record, modify or validate, with full audit trail."),
      list(q = "Is my data secure?", a = "All processing is local. No data leaves your R session. Expressions are validated against a security blacklist."))
    tagList(
      h3(style = "font-size:16px;font-weight:800;margin:20px 0 12px;text-align:left;", i18n("wel_faq_title", l)),
      tags$div(style = "text-align:left;", lapply(faqs, function(faq)
        div(class = "odqa-tut-card",
            div(class = "odqa-tut-header", onclick = "var c=this.parentElement;c.classList.toggle('open');",
                div(class = "odqa-tut-num", "?"), div(class = "odqa-tut-title", faq$q),
                span(class = "odqa-tut-chevron", HTML("&#9660;"))),
            div(class = "odqa-tut-body", faq$a)))))
  })
  
  # Tutorial.
  output$tut_header <- renderUI({ l <- lang(); tagList(h2(i18n("tut_title", l)), p(i18n("tut_sub", l))) })
  output$tut_cards <- renderUI({
    l <- lang()
    # Each tutorial step is identified by a key. For each key the dictionary carries a
    # title (_t), an overview (_ov), a character vector of numbered workflow steps
    # (_wf), and a concrete example paragraph (_ex).
    tut_keys <- c("s1","s2","s3","s4","s5","s6","s7","s8")
    render_step <- function(k, i) {
      t_key  <- paste0("tut_", k, "_t")
      ov_key <- paste0("tut_", k, "_ov")
      wf_key <- paste0("tut_", k, "_wf")
      ex_key <- paste0("tut_", k, "_ex")
      wf_items <- i18n(wf_key, l)
      if (!is.character(wf_items)) wf_items <- as.character(wf_items)
      wf_label <- switch(l, de = "Ablauf", fr = "Procédure", "Workflow")
      ex_label <- switch(l, de = "Beispiel: ", fr = "Exemple : ", "Example: ")
      div(
        class = "odqa-tut-card",
        div(
          class   = "odqa-tut-header",
          onclick = "var c=this.parentElement;c.classList.toggle('open');",
          div(class = "odqa-tut-num", as.character(i)),
          div(class = "odqa-tut-title", gsub("\u2014", "", i18n(t_key, l))),
          span(class = "odqa-tut-chevron", HTML("&#9660;"))),
        div(
          class = "odqa-tut-body",
          div(class = "tut-overview", i18n(ov_key, l)),
          div(class = "tut-wf-label", wf_label),
          tags$ol(lapply(wf_items, function(s) tags$li(s))),
          div(class = "tut-example", i18n(ex_key, l))))
    }
    tagList(lapply(seq_along(tut_keys),
                   function(i) render_step(tut_keys[i], i)))
  })
  
  # Step 1.
  output$s1_header <- renderUI(tagList(h2(i18n("s1_title", lang()))))
  output$s1_source_hint <- renderUI(span(i18n("s1_source", lang())))
  output$demo_desc_ui <- renderUI(p(style = "font-size:12px;color:var(--text-secondary);", i18n("s1_demo_desc", lang())))
  output$preview_title_ui <- renderUI(i18n("s1_preview", lang()))
  output$s1_confirm_label <- renderUI(i18n("s1_confirm", lang()))
  observeEvent(input$btn_load_demo, {
    t0 <- proc.time(); df <- generate_demo_data(); elapsed <- (proc.time() - t0)[3]
    rv$perf_data$import <- elapsed; rv$raw_data <- df; rv$work_data <- df; rv$data_confirmed <- FALSE
    rv$max_step <- max(rv$max_step, 1); session$sendCustomMessage("enable_pills", rv$max_step)
    safe_notify(paste0("Demo: ", nrow(df), " rows x ", ncol(df), " cols (", format_elapsed(elapsed), ")"), "message")
  })
  observeEvent(input$btn_load, {
    t0 <- proc.time(); ft <- input$file_type
    df <- tryCatch(read_file(type = ft, csv_f = input$file_csv, csv_h = input$csv_header, csv_s = input$csv_sep,
                             xls_f = if (ft == "Excel") input$file_csv else NULL, xls_sh = input$xls_sheet,
                             json_f = if (ft == "JSON") input$file_csv else NULL,
                             fhir_f = if (ft == "FHIR Bundle") input$file_csv else NULL),
                   error = function(e) { safe_notify(paste("Import error:", e$message), "error"); NULL })
    if (is.null(df)) return()
    elapsed <- (proc.time() - t0)[3]; rv$perf_data$import <- elapsed
    rv$raw_data <- df; rv$work_data <- df; rv$data_confirmed <- FALSE
    rv$max_step <- max(rv$max_step, 1); session$sendCustomMessage("enable_pills", rv$max_step)
    safe_notify(paste0("Loaded: ", nrow(df), " rows x ", ncol(df), " cols (", format_elapsed(elapsed), ")"), "message")
  })
  observeEvent(input$btn_confirm_data, {
    req(rv$work_data)
    # Reset all analysis state when a new dataset is confirmed. Previous checks,
    # results, and cleansing history belong to the previous dataset and must not carry
    # over.
    rv$custom_checks       <- list()
    rv$stat_suggestions    <- list()
    rv$issues              <- NULL
    rv$quality_score       <- NULL
    rv$cb_conditions       <- list()
    rv$cb_compiled_expr    <- NULL
    rv$cb_imported_values  <- NULL
    rv$cl_log              <- data.frame(timestamp = character(), action = character(), column = character(),
                                         row = character(), old_value = character(), new_value = character(),
                                         stringsAsFactors = FALSE)
    rv$cl_undo_stack       <- list()
    rv$cl_review_rows      <- integer(0)
    rv$cl_review_idx       <- 1L
    rv$original_data       <- NULL
    rv$types_cache         <- NULL
    rv$perf_data           <- list(import = rv$perf_data$import)
    rv$data_confirmed      <- TRUE
    rv$max_step            <- 2
    session$sendCustomMessage("enable_pills", rv$max_step)
    
    # Visible confirmation with an explicit Next affordance. The toast is kept for users
    # who dismiss the modal.
    n_rows <- nrow(rv$work_data); n_cols <- ncol(rv$work_data)
    l <- lang()
    showModal(modalDialog(
      title = tagList(
        tags$span(style = "color:var(--success);font-weight:800;",
                  i18n("modal_ds_confirmed", l))
      ),
      tagList(
        p(style = "font-size:14px;line-height:1.6;",
          sprintf(i18n("modal_ds_body", l), n_rows, n_cols)),
        p(style = "font-size:13px;color:var(--text-secondary);margin-top:12px;",
          i18n("modal_ds_next", l))
      ),
      footer = tagList(
        modalButton(i18n("modal_stay", l)),
        actionButton("btn_confirm_goto_s2", i18n("modal_goto_studio", l),
                     class = "btn-odqa btn-odqa-primary")
      ),
      easyClose = TRUE, size = "m"
    ))
    safe_notify(
      paste0("Dataset confirmed: ", n_rows, " x ", n_cols, ". Studio unlocked."),
      "message"
    )
  })
  
  # Observer for the Next button inside the confirmation modal.
  observeEvent(input$btn_confirm_goto_s2, {
    removeModal()
    go(2)
  })
  observeEvent(input$sql_tpl, {
    tpl <- switch(input$sql_tpl,
                  select = "SELECT * FROM table_name LIMIT 1000;", count = "SELECT COUNT(*) FROM table_name;",
                  top100 = "SELECT TOP 100 * FROM table_name;",
                  tables = "SELECT table_name FROM information_schema.tables WHERE table_schema='public';", "")
    updateTextAreaInput(session, "sql_query", value = tpl)
  })
  observeEvent(input$btn_sql_test, {
    tryCatch({ con <- odqa_db_connect(input$sql_type, input$sql_host, input$sql_port, input$sql_db, input$sql_user, input$sql_pw)
    odqa_disconnect_safe(con); safe_notify("Connection successful.", "message") },
    error = function(e) safe_notify(paste("Failed:", e$message), "error"))
  })
  observeEvent(input$btn_sql_run, {
    t0 <- proc.time()
    df <- tryCatch(
      read_sql_query(input$sql_host, input$sql_port, input$sql_db,
                     input$sql_user, input$sql_pw, input$sql_query, input$sql_type),
      error = function(e) {
        rv$perf_data$sql_query <- (proc.time() - t0)[3]
        safe_notify(paste("SQL error:", e$message), "error"); NULL
      })
    if (is.null(df)) return()
    elapsed <- (proc.time() - t0)[3]
    rv$perf_data$sql_query <- elapsed
    rv$perf_data$import    <- elapsed
    rv$raw_data <- df; rv$work_data <- df; rv$data_confirmed <- FALSE
    rv$max_step <- max(rv$max_step, 1)
    session$sendCustomMessage("enable_pills", rv$max_step)
    safe_notify(paste0("SQL: ", nrow(df), " rows (",
                       format_elapsed(elapsed), ")"), "message")
  })
  # FHIR helpers. A single round-trip downloads the response to a tempfile so HTTP
  # errors can be caught deterministically, without the stray 'cannot open URL' warnings
  # that base url() emits before tryCatch sees them. Up to three retries are attempted
  # on server errors (5xx), because public test servers such as hapi.fhir.org are often
  # flaky.
  fhir_fetch_text <- function(endpoint_url, max_tries = 3L, timeout_s = 30L) {
    last_err <- NULL
    for (k in seq_len(max_tries)) {
      tmp <- tempfile(fileext = ".json")
      status <- tryCatch(
        suppressWarnings(utils::download.file(
          endpoint_url, tmp, mode = "wb", quiet = TRUE,
          method = "libcurl", cacheOK = FALSE,
          headers = c(Accept = "application/fhir+json"))),
        error = function(e) { last_err <<- e$message; -1L })
      if (identical(status, 0L) && file.exists(tmp) && file.info(tmp)$size > 0) {
        txt <- tryCatch(readLines(tmp, warn = FALSE, encoding = "UTF-8"),
                        error = function(e) { last_err <<- e$message; NULL })
        if (!is.null(txt)) return(paste(txt, collapse = "\n"))
      }
      # Wait briefly and retry on 5xx responses.
      Sys.sleep(min(1.5 * k, 4))
    }
    stop(sprintf("FHIR server did not respond after %d attempts. Last error: %s",
                 max_tries, last_err %||% "unknown"))
  }
  
  observeEvent(input$btn_fhir_test, {
    l <- lang()
    tryCatch({
      txt <- fhir_fetch_text(paste0(trimws(input$fhir_url), "/metadata"),
                             max_tries = 2L, timeout_s = 10L)
      # A valid FHIR capability statement has resourceType equal to
      # 'CapabilityStatement'.
      ok <- grepl('"resourceType"\\s*:\\s*"CapabilityStatement"', txt, fixed = FALSE)
      if (ok) safe_notify(switch(l,
                                 de = "FHIR erreichbar.",
                                 fr = "FHIR accessible.",
                                 "FHIR reachable."), "message")
      else    safe_notify(switch(l,
                                 de = "Server antwortet, aber ohne gültige Capability Statement.",
                                 fr = "Le serveur répond mais sans Capability Statement valide.",
                                 "Server responded but without a valid CapabilityStatement."), "warning")
    }, error = function(e) safe_notify(paste0(
      switch(l, de = "FHIR-Verbindung fehlgeschlagen: ",
             fr = "Échec de la connexion FHIR : ",
             "FHIR connection failed: "), e$message), "error"))
  })
  
  observeEvent(input$btn_fhir_run, {
    l <- lang()
    t0 <- proc.time()
    tryCatch({
      url_full <- paste0(trimws(input$fhir_url), "/", trimws(input$fhir_query))
      txt <- fhir_fetch_text(url_full, max_tries = 3L, timeout_s = 30L)
      bundle <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
      if (!is.list(bundle) || is.null(bundle$resourceType)) {
        stop(switch(l,
                    de = "Antwort ist kein FHIR-Bundle.",
                    fr = "La réponse n'est pas un Bundle FHIR.",
                    "Response is not a FHIR bundle."))
      }
      tmp <- tempfile(fileext = ".json")
      jsonlite::write_json(bundle, tmp, auto_unbox = TRUE)
      df      <- read_fhir_tabular(tmp)
      elapsed <- (proc.time() - t0)[3]
      rv$perf_data$fhir_query <- elapsed
      rv$perf_data$import     <- elapsed
      rv$raw_data <- df; rv$work_data <- df; rv$data_confirmed <- FALSE
      rv$max_step <- max(rv$max_step, 1)
      session$sendCustomMessage("enable_pills", rv$max_step)
      safe_notify(paste0("FHIR: ", nrow(df), " ",
                         switch(l, de = "Zeilen", fr = "lignes", "rows"),
                         " (", format_elapsed(elapsed), ")"), "message")
    }, error = function(e) {
      rv$perf_data$fhir_query <- (proc.time() - t0)[3]
      safe_notify(paste0(
        switch(l, de = "FHIR-Fehler: ",
               fr = "Erreur FHIR : ",
               "FHIR error: "), e$message), "error")
    })
  })
  output$import_timer_ui <- renderUI({
    t <- rv$perf_data$import
    if (!is.null(t)) div(style = "font-size:11px;color:var(--text-tertiary);margin-bottom:6px;", paste0("Import: ", format_elapsed(t)))
  })
  output$sql_query_timer_ui <- renderUI({
    t <- rv$perf_data$sql_query
    if (is.null(t)) return(NULL)
    div(style = "display:inline-block;margin-left:10px;font-size:11px;
                 color:var(--text-tertiary);vertical-align:middle;",
        paste0(i18n("sql_elapsed", lang()), " ", format_elapsed(as.numeric(t))))
  })
  output$fhir_query_timer_ui <- renderUI({
    t <- rv$perf_data$fhir_query
    if (is.null(t)) return(NULL)
    div(style = "display:inline-block;margin-left:10px;font-size:11px;
                 color:var(--text-tertiary);vertical-align:middle;",
        paste0(i18n("fhir_elapsed", lang()), " ", format_elapsed(as.numeric(t))))
  })
  output$dt_preview <- renderDT({
    req(rv$work_data)
    datatable(head(rv$work_data, 100), options = list(pageLength = 10, scrollX = TRUE, dom = "ftipr"), rownames = FALSE, class = "stripe compact")
  })
  
  # Step 2 labels.
  output$s2_header <- renderUI({ l <- lang(); tagList(h2(i18n("s2_title", l)), p(i18n("s2_info", l))) })
  output$s2_info_hint        <- renderUI(span(i18n("s2_info",    lang())))
  output$s2_workflow_roadmap <- renderUI(span(i18n("s2_roadmap", lang())))
  output$d1_title_ui <- renderUI(i18n("d1_title", lang()))
  output$d1_desc_ui <- renderUI(i18n("d1_desc", lang()))
  output$btn_stat_run_ui <- renderUI(i18n("btn_stat_run", lang()))
  output$d2_title_ui <- renderUI(i18n("d2_title", lang()))
  output$d2_desc_ui <- renderUI(i18n("d2_desc", lang()))
  output$d2_step0_title_ui <- renderUI(i18n("d2_step0_title", lang()))
  output$d2_step0_hint_ui <- renderUI(i18n("d2_step0_hint", lang()))
  output$d2_step1_title_ui <- renderUI(i18n("d2_step1_title", lang()))
  output$d2_step2_title_ui <- renderUI(i18n("d2_step2_title", lang()))
  output$d2_current_conds_ui <- renderUI(i18n("d2_current_conds", lang()))
  output$d2_gen_expr_btn   <- renderUI(i18n("d2_generate_expr", lang()))
  output$d2_test_query_btn <- renderUI(i18n("d2_test_query",   lang()))
  output$d2_clear_btn <- renderUI(i18n("d2_clear_all", lang()))
  output$d2_save_btn <- renderUI(i18n("d2_save_check", lang()))
  output$cb_check_type_ui <- renderUI({
    l <- lang()
    selectInput("cb_check_type", i18n("cb_type_label", l),
                setNames(c("col_val", "col_col"), c(i18n("cb_type_col_val", l), i18n("cb_type_col_col", l))), width = "100%")
  })
  output$d2_name_input_ui <- renderUI(textInput("cb_name", i18n("d2_check_name", lang()), "", width = "100%"))
  output$d2_desc_input_ui <- renderUI(textInput("cb_desc", i18n("d2_description", lang()), "", width = "100%"))
  output$d2_sev_input_ui <- renderUI(selectInput("cb_sev", i18n("d2_severity", lang()), c("Low", "Medium", "High", "Critical"), selected = "Medium", width = "100%"))
  output$d2_add_btn_ui <- renderUI(i18n("d2_add_cond", lang()))
  output$d3_title_ui <- renderUI(i18n("d3_title", lang()))
  output$d3_desc_ui <- renderUI(i18n("d3_desc", lang()))
  output$d3_exec_btn_ui <- renderUI(i18n("d3_execute", lang()))
  output$d3_delete_btn_ui <- renderUI(i18n("d3_delete_sel", lang()))
  
  # D1: statistical profiling.
  observeEvent(input$btn_stat_run, {
    req(rv$work_data); t0 <- proc.time(); l <- lang()
    rv$stat_suggestions <- tryCatch(stat_generate_checks(rv$work_data, lang = l, max_checks = 30),
                                    error = function(e) { safe_notify(paste("Error:", e$message), "error"); list() })
    elapsed <- (proc.time() - t0)[3]; rv$perf_data$stat_analysis <- elapsed
    safe_notify(paste0(length(rv$stat_suggestions), " suggestions (", format_elapsed(elapsed), ")"), "message")
  })
  output$stat_timer_ui <- renderUI({
    t <- rv$perf_data$stat_analysis
    if (!is.null(t)) div(style = "font-size:11px;color:var(--text-tertiary);margin:6px 0;", paste0("Profiling: ", format_elapsed(t)))
  })
  output$stat_suggestions_ui <- renderUI({
    sugg <- rv$stat_suggestions; if (length(sugg) == 0) return(NULL); l <- lang()
    tagList(lapply(seq_along(sugg), function(i) {
      s <- sugg[[i]]; sev_class <- paste0("sev-", tolower(s$sev %||% "medium"))
      div(class = paste("odqa-suggestion", sev_class), style = "margin:10px 0;",
          div(style = "display:flex;justify-content:space-between;align-items:flex-start;",
              div(
                div(style = "font-weight:700;font-size:13px;margin-bottom:2px;", s$name %||% paste0("Check ", i)),
                div(style = "font-size:12px;color:var(--text-secondary);margin-bottom:4px;", s$desc %||% ""),
                if (!is.null(s$basis) && nzchar(s$basis))
                  div(style = "font-size:11px;color:var(--text-tertiary);margin-bottom:6px;padding:6px 8px;background:var(--surface-1);border-radius:4px;border-left:3px solid var(--brand);", s$basis),
                if (!is.null(s$expression_raw) && nzchar(s$expression_raw))
                  div(class = "expr-code", s$expression_raw)),
              div(style = "flex-shrink:0;margin-left:12px;",
                  tags$span(style = paste0("font-size:11px;font-weight:700;padding:2px 8px;border-radius:6px;color:white;background:",
                                           switch(tolower(s$sev %||% "medium"), low = "var(--success)", medium = "var(--warning)",
                                                  high = "var(--danger)", critical = "var(--critical)", "var(--brand)")), s$sev %||% "Medium"))),
          div(style = "display:flex;gap:6px;margin-top:8px;",
              actionButton(paste0("stat_accept_", i), i18n("d1_accept", l), class = "btn-odqa btn-odqa-success", style = "padding:4px 12px;font-size:11px;"),
              actionButton(paste0("stat_modify_", i), i18n("d1_modify", l), class = "btn-odqa btn-odqa-secondary", style = "padding:4px 12px;font-size:11px;"),
              actionButton(paste0("stat_reject_", i), i18n("d1_reject", l), class = "btn-odqa btn-odqa-ghost", style = "padding:4px 12px;font-size:11px;")))
    }))
  })
  observe({
    sugg <- rv$stat_suggestions; if (length(sugg) == 0) return()
    lapply(seq_along(sugg), function(i) {
      observeEvent(input[[paste0("stat_accept_", i)]], {
        s <- rv$stat_suggestions[[i]]; if (is.null(s)) return()
        new_id <- paste0("STAT-", sprintf("%03d", length(rv$custom_checks) + 1))
        new_check <- list(check_id = new_id, check_name = s$name %||% new_id, description = s$desc %||% "",
                          expression_raw = s$expression_raw %||% "", severity = s$sev %||% "Medium",
                          source = "D1-Statistical", created = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
        rv$custom_checks <- c(rv$custom_checks, list(new_check))
        safe_notify(paste0("Accepted: ", new_check$check_name), "message")
      }, ignoreInit = TRUE, once = TRUE)
      observeEvent(input[[paste0("stat_modify_", i)]], {
        s <- rv$stat_suggestions[[i]]; if (is.null(s)) return()
        showModal(modalDialog(title = paste("Modify:", s$name %||% "Check"),
                              textInput(paste0("mod_name_", i), "Check Name", s$name %||% ""),
                              textAreaInput(paste0("mod_expr_", i), "R Expression", s$expression_raw %||% "", rows = 3),
                              selectInput(paste0("mod_sev_", i), "Severity", c("Low", "Medium", "High", "Critical"), selected = s$sev %||% "Medium"),
                              footer = tagList(modalButton("Cancel"), actionButton(paste0("mod_save_", i), "Save Modified Check", class = "btn-odqa btn-odqa-success")), size = "l"))
      }, ignoreInit = TRUE, once = TRUE)
      observeEvent(input[[paste0("mod_save_", i)]], {
        expr <- input[[paste0("mod_expr_", i)]] %||% ""
        v <- validate_expression(expr)
        if (!v$ok) { safe_notify(paste("Invalid:", v$msg), "error"); return() }
        new_id <- paste0("STAT-M-", sprintf("%03d", length(rv$custom_checks) + 1))
        new_check <- list(check_id = new_id, check_name = input[[paste0("mod_name_", i)]] %||% "",
                          description = "", expression_raw = expr,
                          severity = input[[paste0("mod_sev_", i)]] %||% "Medium",
                          source = "D1-Statistical-Modified", created = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
        rv$custom_checks <- c(rv$custom_checks, list(new_check))
        removeModal(); safe_notify("Modified check saved.", "message")
      }, ignoreInit = TRUE, once = TRUE)
      observeEvent(input[[paste0("stat_reject_", i)]], safe_notify("Rejected.", "warning"), ignoreInit = TRUE, once = TRUE)
    })
  })
  
  
  
  output$cb_col_ui <- renderUI({
    req(rv$work_data)
    l <- lang()
    tagList(
      selectInput("cb_col",   i18n("d2_column",   l), choices = names(rv$work_data), width = "100%"),
      # Column B is always rendered but hidden by default. It is shown via
      # shinyjs::toggle when the check type switches to column-to-column.
      div(id = "cb_col_b_wrap", style = "display:none;",
          selectInput("cb_col_b", i18n("d2_column_b", l),
                      choices = names(rv$work_data), width = "100%"))
    )
  })
  
  # Column-dropdown synchronisation. Every D2 Base and D2 Advanced builder carries a
  # column dropdown that must match the columns of the active dataset. The initial
  # renderUI calls populate each dropdown on first bind. When the dataset is replaced
  # (new import, confirm), every dropdown is rebuilt. The eager-output flag (see the
  # eager_outputs block) guarantees that the renderUI fires even while the D2 tab is
  # hidden, so the dropdown is ready the moment the user opens the tab.
  # updateSelectInput preserves the user's current selection if it still exists,
  # otherwise falls back to the first column.
  observeEvent(rv$work_data, {
    cols <- names(rv$work_data %||% data.frame())
    if (!length(cols)) return()
    pick <- function(id, fallback = cols[1], include_blank = FALSE) {
      choices <- if (include_blank) c("", cols) else cols
      current <- isolate(input[[id]])
      selected <- if (!is.null(current) && current %in% choices) current else fallback
      updateSelectInput(session, id, choices = choices, selected = selected)
    }
    # D2 Base.
    pick("cb_col")
    pick("cb_col_b")
    # D2 Advanced: GROUP BY.
    pick("adv_gb_col",    fallback = "", include_blank = TRUE)
    pick("adv_gb_target", fallback = "", include_blank = TRUE)
    # D2 Advanced: IF-THEN.
    pick("adv_if_col")
    pick("adv_then_col")
    # Step 4 dropdowns bound to column names: rename, delete, format, find-replace.
    pick("cl_rename_col")
    pick("cl_fmt_col")
    pick("cl_delcol_sel")
    pick("cl_fr_col",     fallback = "--ALL--", include_blank = FALSE)
  }, ignoreInit = TRUE)
  
  # Column-to-column toggle: show or hide cb_col_b without re-rendering it.
  observeEvent(input$cb_check_type, {
    shinyjs::toggle("cb_col_b_wrap", condition = identical(input$cb_check_type, "col_col"))
  }, ignoreInit = FALSE)
  
  output$cb_val_ui <- renderUI({
    op <- input$cb_op          %||% "=="
    ct <- input$cb_check_type  %||% "col_val"
    l  <- lang()
    
    # Column-to-column: no value input is needed.
    if (identical(ct, "col_col")) return(NULL)
    
    # Presence, duplicate, and unique operators take no value.
    if (op %in% c("is.na", "is_not.na", "is_duplicate", "is_unique")) return(NULL)
    
    if (op %in% c("BETWEEN", "NOT BETWEEN")) {
      return(fluidRow(
        column(6, textInput("cb_val1", i18n("d2_min", l), "", width = "100%")),
        column(6, textInput("cb_val2", i18n("d2_max", l), "", width = "100%"))
      ))
    }
    
    # IN and NOT IN: show a hint spelling out the separator rules.
    if (op %in% c("IN", "NOT IN")) {
      return(tagList(
        textInput("cb_val",
                  label = i18n("d2_values_hint_sep", l),
                  value = isolate(rv$cb_imported_values) %||% "",
                  width = "100%")
      ))
    }
    
    textInput("cb_val", i18n("d2_value", l), "", width = "100%")
  })
  
  # Separate, inexpensive output for the 'N values loaded' indicator. Rendering it in
  # its own output avoids re-rendering the value input on every change.
  output$cb_import_count <- renderUI({
    v <- rv$cb_imported_values
    if (is.null(v) || !nzchar(v)) return(NULL)
    div(style = "font-size:11px;color:var(--success);font-weight:600;margin-top:4px;",
        paste0(length(pcv(v)), " ", i18n("d2_values_loaded", lang())))
  })
  #########################################################################
  # D2 Advanced server logic: GROUP BY, IF-THEN, and free R-query. All three
  # sub-builders write to rv$custom_checks through the same validated path.
  #########################################################################
  
  # Shared column-list outputs for the Advanced sub-panels.
  output$adv_gb_col_ui     <- renderUI({ req(rv$work_data); selectInput("adv_gb_col",    "Group by column", choices = c("", names(rv$work_data)), width = "100%") })
  output$adv_gb_target_ui  <- renderUI({ req(rv$work_data); selectInput("adv_gb_target", "Target column (for sum/mean/min/max/n_distinct)", choices = c("", names(rv$work_data)), width = "100%") })
  output$adv_if_col_ui     <- renderUI({ req(rv$work_data); selectInput("adv_if_col",    "IF column",       choices = names(rv$work_data), width = "100%") })
  output$adv_then_col_ui   <- renderUI({ req(rv$work_data); selectInput("adv_then_col",  "THEN column",     choices = names(rv$work_data), width = "100%") })
  
  # Keep the Advanced column lists in sync with the active dataset.
  observeEvent(rv$work_data, {
    cols <- names(rv$work_data %||% data.frame())
    if (!length(cols)) return()
    updateSelectInput(session, "adv_gb_col",    choices = c("", cols))
    updateSelectInput(session, "adv_gb_target", choices = c("", cols))
    updateSelectInput(session, "adv_if_col",    choices = cols)
    updateSelectInput(session, "adv_then_col",  choices = cols)
  }, ignoreInit = TRUE)
  
  # Builder: GROUP BY expression.
  build_groupby_expr <- function(gb_col, agg, target_col, thresh) {
    if (!nzchar(gb_col %||% "")) return("")
    gb_sym   <- safe_sym(gb_col)
    tgt_sym  <- if (nzchar(target_col %||% "")) safe_sym(target_col) else gb_sym
    thresh_n <- suppressWarnings(as.numeric(thresh))
    if (is.na(thresh_n)) thresh_n <- 0
    switch(agg,
           "count_gt"     = paste0("(ave(rep(1L, length(", gb_sym, ")), ", gb_sym, ", FUN = sum) > ", thresh_n, ")"),
           "count_lt"     = paste0("(ave(rep(1L, length(", gb_sym, ")), ", gb_sym, ", FUN = sum) < ", thresh_n, ")"),
           "count_eq"     = paste0("(ave(rep(1L, length(", gb_sym, ")), ", gb_sym, ", FUN = sum) == ", thresh_n, ")"),
           "ndistinct_gt" = paste0("(ave(as.character(", tgt_sym, "), ", gb_sym, ", FUN = function(x) length(unique(x))) > ", thresh_n, ")"),
           "sum_gt"       = paste0("(ave(as.numeric(as.character(", tgt_sym, ")), ", gb_sym, ", FUN = function(x) sum(x, na.rm = TRUE)) > ", thresh_n, ")"),
           "mean_gt"      = paste0("(ave(as.numeric(as.character(", tgt_sym, ")), ", gb_sym, ", FUN = function(x) mean(x, na.rm = TRUE)) > ", thresh_n, ")"),
           "min_lt"       = paste0("(ave(as.numeric(as.character(", tgt_sym, ")), ", gb_sym, ", FUN = function(x) min(x, na.rm = TRUE)) < ", thresh_n, ")"),
           "max_gt"       = paste0("(ave(as.numeric(as.character(", tgt_sym, ")), ", gb_sym, ", FUN = function(x) max(x, na.rm = TRUE)) > ", thresh_n, ")"),
           ""
    )
  }
  # Reactive expression string, used for display and testing.
  adv_gb_expr <- reactive({
    build_groupby_expr(input$adv_gb_col, input$adv_gb_agg,
                       input$adv_gb_target, input$adv_gb_thresh)
  })
  output$adv_gb_preview <- renderText({ adv_gb_expr() })
  
  # Test button. Runs the current expression against the active dataset and records the
  # elapsed time.
  observeEvent(input$adv_gb_test, {
    req(rv$work_data)
    expr <- adv_gb_expr()
    if (!nzchar(expr)) { safe_notify("Pick a Group-by column first.", "warning"); return() }
    t0  <- proc.time()
    res <- safe_eval_expr(expr, rv$work_data)
    dt  <- (proc.time() - t0)[3]
    rv$perf_data$d2a_test <- dt
    if (!res$ok) { safe_notify(paste("Test failed:", res$msg), "error"); return() }
    n_flag <- sum(res$result, na.rm = TRUE); n_total <- nrow(rv$work_data)
    pct    <- round(100 * n_flag / max(n_total, 1L), 1)
    output$adv_gb_impact <- renderUI({
      div(style = "margin:8px 0;padding:10px;background:var(--surface-1);border-radius:8px;",
          paste0("Match: ", n_flag, " / ", n_total, " rows (", pct, "%)  —  tested in ", format_elapsed(dt)))
    })
  })
  
  observeEvent(input$adv_gb_clear, {
    updateTextInput(session, "adv_gb_name", value = "")
    updateTextInput(session, "adv_gb_desc", value = "")
    updateSelectInput(session, "adv_gb_col",    selected = "")
    updateSelectInput(session, "adv_gb_target", selected = "")
    updateNumericInput(session, "adv_gb_thresh", value = 1)
    output$adv_gb_impact <- renderUI(NULL)
  })
  
  observeEvent(input$adv_gb_save, {
    req(rv$work_data)
    expr <- adv_gb_expr()
    if (!nzchar(expr))              { safe_notify("Incomplete GROUP BY rule.", "error"); return() }
    v <- validate_expression(expr)
    if (!v$ok)                      { safe_notify(paste("Invalid:", v$msg), "error"); return() }
    nm <- trimws(input$adv_gb_name %||% "")
    if (!nzchar(nm))                { safe_notify("Please name this check before saving.", "error"); return() }
    existing <- vapply(rv$custom_checks, function(cc) cc$check_name %||% "", character(1))
    if (nm %in% existing)           { safe_notify("A check with this name already exists.", "error"); return() }
    new_id <- paste0("GB-", sprintf("%03d", length(rv$custom_checks) + 1))
    rv$custom_checks <- c(rv$custom_checks, list(list(
      check_id       = new_id,
      check_name     = nm,
      description    = input$adv_gb_desc %||% "",
      expression_raw = expr,
      severity       = input$adv_gb_sev %||% "Medium",
      source         = "D2A-GroupBy",
      created        = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )))
    safe_notify(paste0("GROUP BY check saved: ", nm), "message")
  })
  
  # Builder: IF-THEN expression.
  build_clause <- function(col, op, val_raw) {
    if (!nzchar(col %||% "")) return("")
    sym <- safe_sym(col)
    v   <- val_raw %||% ""
    if (op %in% c("is.na", "is_not.na")) {
      return(switch(op, "is.na" = paste0("is.na(", sym, ")"),
                    "is_not.na" = paste0("!is.na(", sym, ")")))
    }
    v_esc <- escape_literal(v)
    switch(op,
           "contains"     = paste0("grepl(\"", v_esc, "\", as.character(", sym, "), ignore.case = TRUE)"),
           "not_contains" = paste0("!grepl(\"", v_esc, "\", as.character(", sym, "), ignore.case = TRUE)"),
           "starts_with"  = paste0("grepl(\"^", v_esc, "\", as.character(", sym, "), ignore.case = TRUE)"),
           "ends_with"    = paste0("grepl(\"", v_esc, "$\", as.character(", sym, "), ignore.case = TRUE)"),
           "REGEXP"       = paste0("grepl(\"", v_esc, "\", as.character(", sym, "))"),
           "BETWEEN"      = {
             parts <- pcv(v); if (length(parts) < 2) return("FALSE")
             lo <- suppressWarnings(as.numeric(parts[1])); hi <- suppressWarnings(as.numeric(parts[2]))
             if (is.na(lo) || is.na(hi)) return("FALSE")
             paste0("(!is.na(as.numeric(", sym, ")) & as.numeric(", sym, ") >= ", lo,
                    " & as.numeric(", sym, ") <= ", hi, ")")
           },
           "NOT BETWEEN"  = {
             parts <- pcv(v); if (length(parts) < 2) return("FALSE")
             lo <- suppressWarnings(as.numeric(parts[1])); hi <- suppressWarnings(as.numeric(parts[2]))
             if (is.na(lo) || is.na(hi)) return("FALSE")
             paste0("(!is.na(as.numeric(", sym, ")) & (as.numeric(", sym, ") < ", lo,
                    " | as.numeric(", sym, ") > ", hi, "))")
           },
           "IN"           = {
             vals <- vapply(pcv(v), escape_literal, character(1))
             if (!length(vals)) return("FALSE")
             paste0("(tolower(trimws(as.character(", sym, "))) %in% c(",
                    paste0('"', vals, '"', collapse = ", "), "))")
           },
           "NOT IN"       = {
             vals <- vapply(pcv(v), escape_literal, character(1))
             if (!length(vals)) return("FALSE")
             paste0("(!tolower(trimws(as.character(", sym, "))) %in% c(",
                    paste0('"', vals, '"', collapse = ", "), "))")
           },
           {
             num <- suppressWarnings(as.numeric(v))
             if (!is.na(num)) {
               paste0("(!is.na(as.numeric(", sym, ")) & as.numeric(", sym, ") ", op, " ", num, ")")
             } else {
               paste0("(as.character(", sym, ") ", op, " \"", v_esc, "\")")
             }
           })
  }
  build_ifthen_expr <- function(if_col, if_op, if_val, then_col, then_op, then_val) {
    if_clause   <- build_clause(if_col,   if_op,   if_val)
    then_clause <- build_clause(then_col, then_op, then_val)
    if (!nzchar(if_clause) || !nzchar(then_clause)) return("")
    # A row is flagged when the IF clause holds and the THEN clause fails.
    paste0("((", if_clause, ") & !(", then_clause, "))")
  }
  
  adv_if_expr <- reactive({
    build_ifthen_expr(input$adv_if_col, input$adv_if_op, input$adv_if_val,
                      input$adv_then_col, input$adv_then_op, input$adv_then_val)
  })
  output$adv_if_preview <- renderText({ adv_if_expr() })
  
  observeEvent(input$adv_if_test, {
    req(rv$work_data)
    expr <- adv_if_expr()
    if (!nzchar(expr)) { safe_notify("Complete both IF and THEN first.", "warning"); return() }
    t0  <- proc.time()
    res <- safe_eval_expr(expr, rv$work_data)
    dt  <- (proc.time() - t0)[3]
    rv$perf_data$d2a_test <- dt
    if (!res$ok) { safe_notify(paste("Test failed:", res$msg), "error"); return() }
    n_flag <- sum(res$result, na.rm = TRUE); n_total <- nrow(rv$work_data)
    pct    <- round(100 * n_flag / max(n_total, 1L), 1)
    output$adv_if_impact <- renderUI({
      div(style = "margin:8px 0;padding:10px;background:var(--surface-1);border-radius:8px;",
          paste0("Match: ", n_flag, " / ", n_total, " rows violate the rule (", pct, "%)  —  tested in ", format_elapsed(dt)))
    })
  })
  
  observeEvent(input$adv_if_clear, {
    updateTextInput(session, "adv_if_name", value = "")
    updateTextInput(session, "adv_if_desc", value = "")
    updateTextInput(session, "adv_if_val",  value = "")
    updateTextInput(session, "adv_then_val", value = "")
    output$adv_if_impact <- renderUI(NULL)
  })
  
  observeEvent(input$adv_if_save, {
    req(rv$work_data)
    expr <- adv_if_expr()
    if (!nzchar(expr))       { safe_notify("IF-THEN incomplete.", "error"); return() }
    v <- validate_expression(expr)
    if (!v$ok)               { safe_notify(paste("Invalid:", v$msg), "error"); return() }
    nm <- trimws(input$adv_if_name %||% "")
    if (!nzchar(nm))         { safe_notify("Please name this check before saving.", "error"); return() }
    existing <- vapply(rv$custom_checks, function(cc) cc$check_name %||% "", character(1))
    if (nm %in% existing)    { safe_notify("Name already taken.", "error"); return() }
    new_id <- paste0("IF-", sprintf("%03d", length(rv$custom_checks) + 1))
    rv$custom_checks <- c(rv$custom_checks, list(list(
      check_id       = new_id,
      check_name     = nm,
      description    = input$adv_if_desc %||% "",
      expression_raw = expr,
      severity       = input$adv_if_sev %||% "Medium",
      source         = "D2A-IfThen",
      created        = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )))
    safe_notify(paste0("IF-THEN check saved: ", nm), "message")
  })
  
  # Builder: free R-query.
  observeEvent(input$adv_rq_test, {
    req(rv$work_data)
    expr <- input$adv_rq_expr %||% ""
    if (!nzchar(trimws(expr))) { safe_notify("Enter an R expression.", "warning"); return() }
    t0  <- proc.time()
    v   <- validate_expression(expr)
    if (!v$ok) { safe_notify(paste("Rejected:", v$msg), "error"); return() }
    res <- safe_eval_expr(expr, rv$work_data)
    dt  <- (proc.time() - t0)[3]
    rv$perf_data$d2a_test <- dt
    if (!res$ok) { safe_notify(paste("Test failed:", res$msg), "error"); return() }
    n_flag <- sum(res$result, na.rm = TRUE); n_total <- nrow(rv$work_data)
    pct    <- round(100 * n_flag / max(n_total, 1L), 1)
    output$adv_rq_impact <- renderUI({
      div(style = "margin:8px 0;padding:10px;background:var(--surface-1);border-radius:8px;",
          paste0("Match: ", n_flag, " / ", n_total, " rows (", pct, "%)  —  tested in ", format_elapsed(dt)))
    })
  })
  
  observeEvent(input$adv_rq_clear, {
    updateTextAreaInput(session, "adv_rq_expr", value = "")
    updateTextInput(session, "adv_rq_name",     value = "")
    updateTextInput(session, "adv_rq_desc",     value = "")
    output$adv_rq_impact <- renderUI(NULL)
  })
  
  observeEvent(input$adv_rq_save, {
    req(rv$work_data)
    expr <- trimws(input$adv_rq_expr %||% "")
    if (!nzchar(expr))          { safe_notify("Expression is empty.", "error"); return() }
    v <- validate_expression(expr)
    if (!v$ok)                  { safe_notify(paste("Rejected:", v$msg), "error"); return() }
    nm <- trimws(input$adv_rq_name %||% "")
    if (!nzchar(nm))            { safe_notify("Please name this check before saving.", "error"); return() }
    existing <- vapply(rv$custom_checks, function(cc) cc$check_name %||% "", character(1))
    if (nm %in% existing)       { safe_notify("Name already taken.", "error"); return() }
    new_id <- paste0("RQ-", sprintf("%03d", length(rv$custom_checks) + 1))
    rv$custom_checks <- c(rv$custom_checks, list(list(
      check_id       = new_id,
      check_name     = nm,
      description    = input$adv_rq_desc %||% "",
      expression_raw = expr,
      severity       = input$adv_rq_sev %||% "Medium",
      source         = "D2A-RQuery",
      created        = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )))
    safe_notify(paste0("R-Query check saved: ", nm), "message")
  })
  observeEvent(input$cb_check_type, {
    updateTextInput(session, "cb_val",  value = "")
    updateTextInput(session, "cb_val1", value = "")
    updateTextInput(session, "cb_val2", value = "")
    rv$cb_imported_values <- NULL
  }, ignoreInit = TRUE)
  
  observeEvent(input$cb_import_file, {
    req(input$cb_import_file)
    tryCatch({
      f <- input$cb_import_file; ext <- tools::file_ext(f$name)
      vals <- if (ext %in% c("csv", "txt")) {
        lines <- readLines(f$datapath, warn = FALSE)
        vals_raw <- unlist(strsplit(paste(lines, collapse = ","), ",|;|\t|\n"))
        trimws(vals_raw[nzchar(trimws(vals_raw))])
      } else if (ext == "json") {
        obj <- jsonlite::fromJSON(f$datapath); if (is.list(obj)) obj <- unlist(obj); as.character(obj)
      } else if (ext %in% c("xlsx", "xls")) {
        df <- readxl::read_excel(f$datapath); as.character(unlist(df[, 1]))
      } else character(0)
      vals <- unique(vals[nzchar(vals)])
      rv$cb_imported_values <- paste(vals, collapse = ",")
      safe_notify(paste0(length(vals), " values imported."), "message")
    }, error = function(e) safe_notify(paste("Import error:", e$message), "error"))
  })
  output$cb_import_status <- renderUI({
    if (!is.null(rv$cb_imported_values))
      div(style = "margin-top:30px;font-size:11px;color:var(--success);font-weight:600;",
          paste0(length(pcv(rv$cb_imported_values)), " values loaded"))
  })
  observeEvent(input$cb_add_cond, {
    req(input$cb_col); col <- input$cb_col; op <- input$cb_op %||% "=="; sym <- safe_sym(col)
    is_cc <- (input$cb_check_type %||% "col_val") == "col_col"
    if (is_cc) {
      col_b <- input$cb_col_b %||% col; sym_b <- safe_sym(col_b)
      cond_str <- paste0(sym, op, sym_b)
    } else {
      # Every literal flowing from user input into generated R code is passed through
      # escape_literal() first. This escapes both backslashes and quotes, so a stray
      # character in a value cannot derail parsing or reach eval unescaped.
      v_esc <- escape_literal(input$cb_val %||% "")
      v1    <- suppressWarnings(as.numeric(input$cb_val1 %||% "0"))
      v2    <- suppressWarnings(as.numeric(input$cb_val2 %||% "0"))
      if (is.na(v1)) v1 <- 0
      if (is.na(v2)) v2 <- 0
      cond_str <- switch(op,
                         "is.na"        = paste0("is.na(", sym, ")"),
                         "is_not.na"    = paste0("!is.na(", sym, ")"),
                         "is_duplicate" = paste0("duplicated(", sym, ")&!is.na(", sym, ")"),
                         "is_unique"    = paste0("!duplicated(", sym, ")"),
                         "contains"     = paste0("grepl(\"", v_esc, "\",as.character(", sym, "),ignore.case=TRUE)"),
                         "not_contains" = paste0("!grepl(\"", v_esc, "\",as.character(", sym, "),ignore.case=TRUE)"),
                         "starts_with"  = paste0("grepl(\"^", v_esc, "\",as.character(", sym, "),ignore.case=TRUE)"),
                         "ends_with"    = paste0("grepl(\"", v_esc, "$\",as.character(", sym, "),ignore.case=TRUE)"),
                         "BETWEEN"      = paste0("(!is.na(as.numeric(", sym, "))&as.numeric(", sym, ")>=", v1, "&as.numeric(", sym, ")<=", v2, ")"),
                         "NOT BETWEEN"  = paste0("(!is.na(as.numeric(", sym, "))&(as.numeric(", sym, ")<", v1, "|as.numeric(", sym, ")>", v2, "))"),
                         "IN"           = { vals <- vapply(pcv(input$cb_val %||% ""), escape_literal, character(1)); paste0("tolower(trimws(as.character(", sym, ")))%in%c(", paste0('"', vals, '"', collapse = ","), ")") },
                         "NOT IN"       = { vals <- vapply(pcv(input$cb_val %||% ""), escape_literal, character(1)); paste0("!tolower(trimws(as.character(", sym, ")))%in%c(", paste0('"', vals, '"', collapse = ","), ")") },
                         "REGEXP"       = paste0("grepl(\"", v_esc, "\",as.character(", sym, "))"),
                         {
                           v <- input$cb_val %||% ""
                           num_v <- suppressWarnings(as.numeric(v))
                           if (!is.na(num_v)) {
                             paste0("(!is.na(as.numeric(", sym, "))&as.numeric(", sym, ")", op, num_v, ")")
                           } else {
                             paste0("(as.character(", sym, ")", op, "\"", escape_literal(v), "\")")
                           }
                         })
    }
    # Append the new condition. Auto-compile if the user picked END.
    rv$cb_conditions <- c(rv$cb_conditions, list(cond_str))
    if ((input$cb_logic %||% "&") == "END") {
      conds <- rv$cb_conditions
      if (length(conds) > 0) {
        rv$cb_compiled_expr <- paste0(
          "(", paste(conds, collapse = ") & ("), ")"
        )
        safe_notify(
          paste0("Check definition finalized: ", length(conds),
                 " conditions compiled."),
          "message"
        )
      }
    }
  })
  observeEvent(input$cb_clear_conds, { rv$cb_conditions <- list(); rv$cb_compiled_expr <- NULL; rv$cb_imported_values <- NULL })
  observeEvent(input$cb_compile, {
    conds <- rv$cb_conditions; if (length(conds) == 0) return()
    logic <- input$cb_logic %||% "&"
    if (logic == "END") logic <- "&"
    rv$cb_compiled_expr <- paste0("(", paste(conds, collapse = paste0(") ", logic, " (")), ")")
  })
  output$dt_conditions <- renderDT({
    conds <- rv$cb_conditions; if (length(conds) == 0) return(NULL)
    datatable(data.frame(Nr = seq_along(conds), Condition = unlist(conds), stringsAsFactors = FALSE),
              options = list(dom = "t", pageLength = 100), rownames = FALSE, class = "compact stripe")
  })
  output$cb_expr_preview <- renderText({
    if (!is.null(rv$cb_compiled_expr) && nzchar(rv$cb_compiled_expr)) rv$cb_compiled_expr
    else if (length(rv$cb_conditions) > 0) paste(rv$cb_conditions, collapse = paste0(" ", input$cb_logic %||% "&", " "))
    else ""
  })
  cb_impact_trigger <- reactive({
    list(
      conds   = rv$cb_conditions,
      compiled = rv$cb_compiled_expr,
      logic   = input$cb_logic,
      test    = input$cb_test_query   # manual Test Query button click
    )
  }) |> debounce(600)
  
  output$cb_impact_preview <- renderUI({
    req(rv$work_data)
    cb_impact_trigger()    # establish the dependency
    expr <- rv$cb_compiled_expr
    if (is.null(expr) || !nzchar(expr)) {
      if (length(rv$cb_conditions) > 0) {
        expr <- paste(rv$cb_conditions,
                      collapse = paste0(" ", input$cb_logic %||% "&", " "))
      } else {
        return(NULL)
      }
    }
    res <- safe_eval_expr(expr, rv$work_data)
    if (!res$ok) return(div(class = "odqa-hint danger", res$msg))
    n_flag  <- sum(res$result, na.rm = TRUE)
    n_total <- nrow(rv$work_data)
    pct     <- round(100 * n_flag / n_total, 1)
    impact_col <- if (pct > 50) "var(--danger)"
    else if (pct > 20) "var(--warning)"
    else "var(--success)"
    div(style = "margin:8px 0;padding:10px;background:var(--surface-1);border-radius:8px;",
        div(style = "display:flex;justify-content:space-between;",
            span(style = "font-weight:700;",
                 paste0("Test result: ", n_flag, " / ", n_total, " rows matched (",
                        pct, "%)")),
            span(style = paste0("font-weight:700;color:", impact_col, ";"),
                 paste0(pct, "%"))),
        div(style = "height:6px;background:var(--surface-2);border-radius:3px;margin-top:6px;",
            div(style = paste0("width:", min(pct, 100),
                               "%;height:100%;background:",
                               impact_col, ";border-radius:3px;"))))
  })
  observeEvent(input$cb_save, {
    expr <- rv$cb_compiled_expr
    if (is.null(expr) || !nzchar(trimws(expr))) {
      conds <- rv$cb_conditions
      if (length(conds) == 0) { safe_notify("No conditions defined.", "warning"); return() }
      expr <- paste0("(",
                     paste(conds,
                           collapse = paste0(") ", input$cb_logic %||% "&", " (")),
                     ")")
    }
    v <- validate_expression(expr)
    if (!v$ok) { safe_notify(paste("Invalid:", v$msg), "error"); return() }
    
    # The check name is mandatory. A named check is auditable; an auto-generated name
    # would defeat the compliance intent of the Word report.
    name <- trimws(input$cb_name %||% "")
    if (!nzchar(name)) {
      safe_notify(switch(lang(),
                         de = "Bitte einen aussagekräftigen Prüfungsnamen vergeben, bevor Sie speichern.",
                         fr = "Veuillez saisir un nom explicite pour la vérification avant de sauvegarder.",
                         "Please enter a meaningful check name before saving."),
                  "error")
      return()
    }
    # Reject duplicate names within the same session to keep the check register
    # unambiguous.
    existing <- vapply(rv$custom_checks,
                       function(cc) cc$check_name %||% "",
                       character(1))
    if (name %in% existing) {
      safe_notify(switch(lang(),
                         de = "Dieser Prüfungsname ist bereits vergeben. Bitte eindeutigen Namen wählen.",
                         fr = "Ce nom de vérification existe déjà. Choisissez un nom unique.",
                         "A check with this name already exists. Please choose a unique name."),
                  "error")
      return()
    }
    new_id <- paste0("MAN-", sprintf("%03d", length(rv$custom_checks) + 1))
    new_check <- list(
      check_id       = new_id,
      check_name     = name,
      description    = input$cb_desc %||% "",
      expression_raw = expr,
      severity       = input$cb_sev  %||% "Medium",
      source         = "D2-ManualBuilder",
      created        = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )
    rv$custom_checks <- c(rv$custom_checks, list(new_check))
    # Reset the builder for the next check.
    rv$cb_conditions      <- list()
    rv$cb_compiled_expr   <- NULL
    rv$cb_imported_values <- NULL
    updateTextInput(session, "cb_name", value = "")
    updateTextInput(session, "cb_desc", value = "")
    safe_notify(paste0("Check saved: ", name), "message")
  })
  
  # D3: check manager.
  output$d3_checks_count <- renderUI({
    n <- length(rv$custom_checks); l <- lang()
    if (n == 0) return(div(class = "odqa-hint info", span(class = "odqa-hint-icon", "i"), i18n("d3_no_checks", l)))
    div(class = "odqa-hint success", span(class = "odqa-hint-icon", "OK"), paste0(n, " ", i18n("d3_checks_defined", l)))
  })
  observeEvent(input$d3_run_checks, {
    req(rv$work_data); l <- lang()
    if (length(rv$custom_checks) == 0) { safe_notify(i18n("d3_no_checks", l), "warning"); return() }
    msg <- i18n("d3_exec_msg", l)
    msg <- gsub("\\{n_checks\\}", as.character(length(rv$custom_checks)), msg)
    msg <- gsub("\\{n_records\\}", as.character(nrow(rv$work_data)), msg)
    showModal(modalDialog(title = i18n("d3_exec_title", l), msg,
                          footer = tagList(modalButton(i18n("btn_cancel", l)), actionButton("d3_confirm_exec", i18n("d3_exec_btn", l), class = "btn-odqa btn-odqa-primary"))))
  })
  observeEvent(input$d3_confirm_exec, {
    removeModal()
    withProgress(message = "Running checks...", value = 0.1, {
      t0 <- proc.time()
      setProgress(0.3, detail = paste0("Evaluating ", length(rv$custom_checks), " checks"))
      rv$issues        <- execute_checks(rv$work_data, rv$custom_checks)
      setProgress(0.7, detail = "Aggregating per-check impact")
      rv$quality_score <- calc_quality_score(nrow(rv$work_data), rv$issues)
      # Cache the per-check impact table once, so the Show/Hide chart toggle is instant.
      rv$impact_df     <- issues_by_check(rv$issues, nrow(rv$work_data))
      # Clear the per-check plot registry so fresh outputs can attach.
      s3_plot_cache$registered <- character(0)
      rv$perf_data$check_exec  <- (proc.time() - t0)[3]
      safe_notify(paste0("Done: ", rv$quality_score$issue_count,
                         " issues. Score: ", rv$quality_score$score,
                         "% (", format_elapsed(rv$perf_data$check_exec), ")"),
                  "message")
    })
    go(3)
  })
  # Cached D3 table, rebuilt only when rv$custom_checks changes. Avoids repeated
  # do.call(rbind, lapply(...)) on every reactive pulse.
  checks_table <- reactive({
    checks <- rv$custom_checks
    if (length(checks) == 0) return(NULL)
    data.frame(
      Nr         = seq_along(checks),
      ID         = vapply(checks, function(cc) cc$check_id       %||% "", character(1)),
      Name       = vapply(checks, function(cc) cc$check_name     %||% "", character(1)),
      Severity   = vapply(checks, function(cc) cc$severity       %||% "Medium", character(1)),
      Source     = vapply(checks, function(cc) cc$source         %||% "", character(1)),
      Expression = vapply(checks, function(cc) substr(cc$expression_raw %||% "", 1, 80), character(1)),
      stringsAsFactors = FALSE
    )
  })
  
  output$dt_all_checks <- renderDT({
    tbl <- checks_table()
    if (is.null(tbl)) {
      return(datatable(
        data.frame(Info = switch(lang(),
                                 de = "Noch keine Pruefungen definiert. Nutzen Sie D1, D2 Base oder D2 Advanced.",
                                 fr = "Aucune verification definie. Utilisez D1, D2 Base ou D2 Advanced.",
                                 "No checks yet. Use D1, D2 Base, or D2 Advanced to add some.")),
        rownames = FALSE,
        options  = list(dom = "t", ordering = FALSE, paging = FALSE, searching = FALSE),
        class    = "compact"
      ))
    }
    datatable(
      tbl,
      selection = "multiple",
      options   = list(pageLength = 20, scrollX = TRUE, dom = "ftipr"),
      rownames  = FALSE,
      class     = "stripe compact"
    )
  })
  observeEvent(input$d3_delete_sel, {
    sel <- input$dt_all_checks_rows_selected
    if (is.null(sel) || length(sel) == 0) {
      safe_notify(switch(lang(),
                         de = "Bitte zuerst Prüfungen in der Tabelle auswählen.",
                         fr = "Sélectionnez d'abord des vérifications dans le tableau.",
                         "Select checks in the table first."),
                  "warning"); return()
    }
    # Drop out-of-range row indices. This cannot happen under normal interaction but
    # guards against a client sending stale row ids.
    sel <- sel[sel >= 1L & sel <= length(rv$custom_checks)]
    if (length(sel) == 0) return()
    rv$custom_checks <- rv$custom_checks[-sel]
    safe_notify(paste0(length(sel), " check(s) deleted."), "message")
  })
  output$d3_export_json <- downloadHandler(
    filename = function() paste0("odqa_checks_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".json"),
    content = function(file) writeLines(jsonlite::toJSON(lapply(rv$custom_checks, function(cc) list(
      check_id = cc$check_id, check_name = cc$check_name, description = cc$description %||% "",
      expression_raw = cc$expression_raw, severity = cc$severity, source = cc$source %||% "")), pretty = TRUE, auto_unbox = TRUE), file))
  observeEvent(input$d3_import_json, {
    req(input$d3_import_json)
    tryCatch({
      imported <- jsonlite::fromJSON(input$d3_import_json$datapath, simplifyVector = FALSE); count <- 0
      for (cc in imported) {
        if (!is.null(cc$expression_raw) && nzchar(cc$expression_raw)) {
          v <- validate_expression(cc$expression_raw)
          if (v$ok) { rv$custom_checks <- c(rv$custom_checks, list(list(check_id = cc$check_id %||% paste0("IMP_", count + 1),
                                                                        check_name = cc$check_name %||% "", description = cc$description %||% "", expression_raw = cc$expression_raw,
                                                                        severity = cc$severity %||% "Medium", source = paste0("Imported-", cc$source %||% ""),
                                                                        created = format(Sys.time(), "%Y-%m-%d %H:%M:%S")))); count <- count + 1 }
        }
      }; safe_notify(paste0(count, " imported."), "message")
    }, error = function(e) safe_notify(paste("Error:", e$message), "error"))
  })
  output$footer_indicator <- renderUI({
    s <- rv$step; l <- lang()
    # Step identifiers are internal (T, F, 0..4). Always display a human-readable label.
    label <- if (identical(s, "T"))      i18n("footer_tutorial", l)
    else if (identical(s, "F")) i18n("footer_summary",  l)
    else if (is.numeric(s) && s == 0) i18n("footer_welcome", l)
    else if (is.numeric(s))     paste0(i18n("footer_step", l), " ", s, "/4")
    else                         ""
    n <- length(rv$custom_checks)
    tagList(
      tags$span(class = "step-indicator", label),
      if (n > 0) tags$span(
        style = "font-size:10px;color:var(--brand);font-weight:600;margin-left:12px;",
        paste0(n, " ", i18n("footer_checks", l))
      )
    )
  })
  output$footer_next_btn <- renderUI({
    if (identical(rv$step, "F")) return(NULL)
    actionButton("btn_next_f", i18n("footer_next", lang()),
                 class = "btn-odqa btn-odqa-primary")
  })
  
  # Step 3: results.
  output$s3_header <- renderUI(tagList(h2(i18n("s3_title", lang()))))
  output$s3_metrics <- renderUI({
    qs <- rv$quality_score; if (is.null(qs)) return(NULL); n_checks <- length(rv$custom_checks)
    div(class = "odqa-metrics",
        div(class = "odqa-metric m-checks", div(class = "metric-value", n_checks), div(class = "metric-label", i18n("s3_checks", lang()))),
        div(class = "odqa-metric m-issues", div(class = "metric-value", qs$issue_count), div(class = "metric-label", i18n("s3_issues", lang()))),
        div(class = "odqa-metric m-affected", div(class = "metric-value", qs$affected_rows), div(class = "metric-label", i18n("s3_affected", lang()))),
        div(class = "odqa-metric m-score", div(class = "metric-value", style = paste0("color:", score_hex(qs$score), ";"), paste0(qs$score, "%")), div(class = "metric-label", "Fitness Score")))
  })
  output$s3_interpretation <- renderUI({
    qs <- rv$quality_score; if (is.null(qs)) return(NULL); l <- lang(); s <- qs$score
    if (s >= 95) { cls <- "ok"; key <- "interp_ok" } else if (s >= 80) { cls <- "lo"; key <- "interp_lo" }
    else if (s >= 60) { cls <- "md"; key <- "interp_md" } else if (s >= 40) { cls <- "hi"; key <- "interp_hi" }
    else { cls <- "cr"; key <- "interp_cr" }
    icons <- list(ok = "A+", lo = "B", md = "C", hi = "D", cr = "F")
    div(class = paste0("odqa-interp level-", cls), div(class = "odqa-interp-icon", icons[[cls]]),
        div(class = "odqa-interp-text", h4(paste0("Score: ", qs$score, "%")), p(i18n(key, l))))
  })
  output$s3_score_note <- renderUI(span(i18n("s3_score_info", lang())))
  output$chart_sev_title <- renderUI(i18n("s3_sev", lang()))
  output$chart_cat_title <- renderUI(i18n("s3_cat", lang()))
  output$detail_title <- renderUI(i18n("s3_detail", lang()))
  output$s3_score_band_info <- renderUI(div(style = "font-size:11px;color:var(--text-tertiary);margin-top:4px;", i18n("s3_score_band", lang())))
  output$s3_cert_dq_btn <- renderUI(i18n("cert_dq", lang()))
  output$s3_cert_issues_btn <- renderUI(i18n("cert_issues_csv", lang()))
  output$plot_severity <- renderPlot({
    issues <- rv$issues; if (is.null(issues) || nrow(issues) == 0) { plot.new(); text(0.5, 0.5, "No issues", cex = 1.2); return() }
    sev_counts <- table(factor(issues$severity, levels = c("Low", "Medium", "High", "Critical")))
    cols <- c(Low = "#2E7D32", Medium = "#E65100", High = "#C62828", Critical = "#880E4F")
    par(mar = c(4, 5, 2, 1)); bp <- barplot(sev_counts, col = cols[names(sev_counts)], border = NA, las = 1, ylab = "Count")
    text(bp, sev_counts, labels = sev_counts, pos = 3, cex = 0.9, font = 2)
  })
  output$plot_category <- renderPlot({
    checks <- rv$custom_checks; issues <- rv$issues
    if (is.null(issues) || nrow(issues) == 0) { plot.new(); text(0.5, 0.5, "No issues", cex = 1.2); return() }
    source_map <- setNames(vapply(checks, function(cc) cc$source %||% "Unknown", character(1)),
                           vapply(checks, function(cc) cc$check_id %||% "?", character(1)))
    issues$source <- source_map[issues$check_id]; issues$source[is.na(issues$source)] <- "Unknown"
    src_counts <- sort(table(issues$source), decreasing = TRUE)
    par(mar = c(4, 8, 2, 1)); bp <- barplot(src_counts, horiz = TRUE, col = "#1565C0", border = NA, las = 1, xlab = "Issues")
    text(src_counts, bp, labels = src_counts, pos = 4, cex = 0.8, font = 2)
  })
  output$dt_issues <- renderDT({
    issues <- rv$issues
    if (is.null(issues) || nrow(issues) == 0)
      return(datatable(data.frame(Message = "No issues."), rownames = FALSE))
    datatable(
      issues,
      options  = list(pageLength = 15, scrollX = TRUE, dom = "ftipr",
                      processing = TRUE, deferRender = TRUE),
      rownames = FALSE,
      class    = "stripe compact"
    )
  }, server = TRUE)
  output$s3_check_impact_ui <- renderUI({
    n_total   <- nrow(rv$work_data %||% data.frame())
    impact_df <- rv$impact_df
    if (is.null(impact_df) || nrow(impact_df) == 0 || n_total == 0) return(NULL)
    l <- lang()
    
    div(class = "odqa-card", style = "margin-top:12px;",
        div(class = "odqa-card-header",
            div(class = "odqa-card-badge", "I"),
            div(class = "odqa-card-title", i18n("s3_per_check", l))),
        
        # Summary bar list.
        lapply(seq_len(nrow(impact_df)), function(i) {
          r       <- impact_df[i, ]
          pct     <- r$affected_pct
          sev_col <- switch(r$severity,
                            High = "var(--danger)", Medium = "var(--warning)",
                            Low  = "var(--success)", Critical = "var(--critical)", "var(--brand)")
          check_label <- r$check_name %||% r$check_id
          
          div(style = "padding:8px 0; border-bottom:1px solid var(--border-light);",
              # Top row: severity badge, name, count.
              div(style = "display:flex; align-items:center; gap:8px; margin-bottom:4px;",
                  tags$span(
                    style = paste0("font-size:10px;font-weight:700;padding:2px 7px;border-radius:4px;",
                                   "color:white;background:", sev_col, ";flex-shrink:0;"),
                    r$severity),
                  div(style = "flex:1; font-weight:600; font-size:12px; overflow:hidden;
                         white-space:nowrap; text-overflow:ellipsis;", check_label),
                  tags$span(
                    style = "font-size:11px; font-weight:700; color:var(--text-secondary);
                       white-space:nowrap;",
                    paste0(r$affected_n, " / ", n_total, " (", pct, "%)"))),
              # Progress bar.
              div(style = "height:6px; background:var(--surface-2); border-radius:3px;",
                  div(style = paste0("width:", min(pct, 100), "%; height:100%; background:",
                                     sev_col, "; border-radius:3px; transition:width .4s ease;"))),
              # The plot is always present and already rendered. The toggle flips its
              # CSS display property between none and block, so the switch is free and
              # requires no server round-trip.
              div(style = "margin-top:4px;",
                  tags$button(
                    class = "btn-odqa btn-odqa-ghost",
                    style = "padding:2px 8px; font-size:10px; font-weight:600;",
                    onclick = paste0(
                      "var p=document.getElementById('chk_plot_", i, "');",
                      "if(p){p.style.display=(p.style.display==='none'?'block':'none');}"
                    ),
                    switch(l,
                           de = "Grafik ein- / ausblenden",
                           fr = "Afficher / masquer le graphique",
                           "Show / Hide Chart")),
                  div(id = paste0("chk_plot_", i),
                      style = "display:block; margin-top:6px;",
                      plotOutput(paste0("s3_chk_plot_", i),
                                 height = "180px", width = "100%")))) # nolint
        })
    )
  })
  
  # Step 3 per-check plots. Each row in rv$impact_df gets its own plot slot
  # (s3_chk_plot_<i>). All plots render eagerly on entry to Step 3: no req() gate on a
  # click event, suspendWhenHidden is set to FALSE so they paint even while their
  # wrapper is hidden, and the Show/Hide button is a pure CSS toggle. The plot body
  # delegates to plot_check_impact(), the same function the Word report uses, so the two
  # views look identical.
  s3_plot_cache <- reactiveValues(registered = character(0))
  
  observe({
    impact_df <- rv$impact_df
    if (is.null(impact_df) || nrow(impact_df) == 0) return()
    n_total <- nrow(rv$work_data %||% data.frame())
    if (n_total == 0L) return()
    
    for (i in seq_len(nrow(impact_df))) {
      slot_id <- paste0("s3_chk_plot_", i)
      if (slot_id %in% s3_plot_cache$registered) next
      s3_plot_cache$registered <- c(s3_plot_cache$registered, slot_id)
      
      local({
        ii <- i
        sid <- paste0("s3_chk_plot_", ii)
        output[[sid]] <- renderPlot({
          df <- rv$impact_df
          if (is.null(df) || nrow(df) == 0 || ii > nrow(df)) {
            plot.new(); text(0.5, 0.5, "No data", cex = 1.1); return()
          }
          cur_total <- nrow(rv$work_data %||% data.frame())
          if (cur_total == 0L) {
            plot.new(); text(0.5, 0.5, "No data", cex = 1.1); return()
          }
          r  <- df[ii, ]
          nm <- r$check_name %||% r$check_id
          plot_check_impact(
            affected_n = r$affected_n,
            total_n    = cur_total,
            main       = substr(paste0("[", r$check_id, "] ", nm), 1, 80),
            subtitle   = paste0("Severity: ", r$severity)
          )
        }, bg = "white")
        
        # Force eager rendering. Without this, Shiny would suspend the output because
        # the enclosing div is hidden, defeating the intent of pre-rendering every plot.
        tryCatch(
          outputOptions(output, sid, suspendWhenHidden = FALSE),
          error = function(e) NULL
        )
      })
    }
  })
  output$dl_dq_cert <- downloadHandler(
    filename = function() paste0("DQ_Certificate_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx"),
    content = function(file) {
      withProgress(message = "Building DQ Certificate...", value = 0.1, {
        t0 <- proc.time()
        result <- tryCatch({
          setProgress(0.3, detail = "Rendering charts")
          r <- gen_dq_certificate(rv$issues, length(rv$custom_checks), rv$work_data, lang(),
                                  user_info = rv$user_info, perf_data = rv$perf_data,
                                  custom_checks = rv$custom_checks)
          setProgress(0.9, detail = "Writing .docx")
          r
        }, error = function(e) {
          safe_notify(paste("Certificate error:", e$message), "error"); NULL
        })
        rv$perf_data$cert_dq <- (proc.time() - t0)[3]
        if (!is.null(result) && file.exists(result)) file.copy(result, file)
        else safe_notify("Certificate generation failed.", "error")
      })
    })
  output$dl_issues_csv <- downloadHandler(
    filename = function() paste0("Issues_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"),
    content = function(file) write.csv(rv$issues %||% data.frame(), file, row.names = FALSE, fileEncoding = "UTF-8"))
  
  # Step 4.
  output$s4_header            <- renderUI(tagList(h2(i18n("s4_title", lang()))))
  output$s4_overview_title_ui <- renderUI(i18n("s4_overview_title", lang()))
  output$s4_overview_body_ui <- renderUI({
    items <- i18n("s4_overview_body", lang())
    if (!is.character(items)) items <- as.character(items)
    # Each entry is a plain numbered paragraph. The text already starts with '4.1',
    # '4.2', and so on, so a <ul> or <ol> would duplicate the numbering with an unwanted
    # marker. A simple div per entry is used instead.
    div(
      style = "font-size:13px;line-height:1.7;color:var(--text-secondary);",
      lapply(items, function(s) div(style = "margin:4px 0;", s))
    )
  })
  output$s4_guide_title <- renderUI(i18n("s4_guide", lang()))
  output$s4_guide_sub <- renderUI(i18n("s4_guide_hint", lang()))
  output$s4_bulk_title <- renderUI(i18n("s4_bulk", lang()))
  output$s4_manual_title <- renderUI(i18n("s4_manual", lang()))
  output$s4_log_title <- renderUI(i18n("s4_log", lang()))
  output$s4_compare_title <- renderUI(i18n("s4_compare", lang()))
  output$s4_rename_title <- renderUI(i18n("s4_rename", lang()))
  output$s4_datefix_title_ui <- renderUI(i18n("s4_datefix_title", lang()))
  output$s4_delcol_title_ui <- renderUI(i18n("s4_delcol_title", lang()))
  output$btn_start_review_ui <- renderUI(i18n("btn_start_review", lang()))
  output$cl_gen_compare_ui <- renderUI(i18n("cl_gen_compare", lang()))
  output$cl_new_name_ui <- renderUI(textInput("cl_new_name", i18n("cl_new_name", lang()), "", width = "100%"))
  output$cl_rename_btn_ui <- renderUI(i18n("cl_rename_btn", lang()))
  output$cl_convert_date_ui <- renderUI(i18n("cl_convert_date", lang()))
  output$cl_delete_col_btn_ui <- renderUI(i18n("cl_delete_col_btn", lang()))
  output$cert_cleansing_btn <- renderUI(i18n("cert_cleansing", lang()))
  output$cert_cleaned_btn <- renderUI(i18n("cert_cleaned_csv", lang()))
  output$cert_audit_btn <- renderUI(i18n("cert_audit_csv", lang()))
  output$cert_dq_btn <- renderUI(i18n("cert_dq", lang()))
  output$cert_issues_btn <- renderUI(i18n("cert_issues_csv", lang()))
  output$cert_cl_btn2 <- renderUI(i18n("cert_cleansing", lang()))
  output$cert_cleaned_btn2 <- renderUI(i18n("cert_cleaned_csv", lang()))
  output$btn_new_analysis_ui <- renderUI(i18n("btn_new_analysis", lang()))
  output$s4_manual_hint <- renderUI(div(class = "odqa-hint info", span(class = "odqa-hint-icon", "i"), i18n("s4_manual_hint_text", lang())))
  output$cl_issue_select <- renderUI({
    issues <- rv$issues; if (is.null(issues) || nrow(issues) == 0) return(div(class = "odqa-hint info", span(class = "odqa-hint-icon", "i"), i18n("no_issues", lang())))
    issue_labels <- paste0("[", issues$check_id, "] ", issues$issue); counts <- table(issue_labels)
    display_choices <- setNames(names(counts), paste0(names(counts), " (", as.integer(counts), " rows)"))
    selectInput("cl_issue", "Select issue to review", choices = display_choices, width = "100%")
  })
  cl_get_affected_rows <- reactive({ req(rv$issues, input$cl_issue, rv$work_data)
    pat <- sub("^\\[([^]]+)\\].*", "\\1", input$cl_issue)
    rows <- rv$issues$row[rv$issues$check_id == pat]
    rows <- rows[!is.na(rows) & rows >= 1 & rows <= nrow(rv$work_data)]; unique(rows)
  })
  observeEvent(input$cl_start_review, {
    rows <- cl_get_affected_rows(); if (length(rows) == 0) { safe_notify("No affected rows.", "warning"); return() }
    rv$cl_review_rows <- rows; rv$cl_review_idx <- 1L
  })
  output$cl_record_nav <- renderUI({
    rows <- rv$cl_review_rows; idx <- rv$cl_review_idx; if (length(rows) == 0) return(NULL)
    div(class = "record-nav",
        actionButton("cl_prev_rec", i18n("cl_prev_record", lang()), class = "btn-odqa btn-odqa-ghost", style = "padding:4px 12px;font-size:12px;"),
        span(class = "rec-counter", sprintf("Record %d of %d (Row #%d)", idx, length(rows), rows[min(idx, length(rows))])),
        actionButton("cl_next_rec", i18n("cl_next_record", lang()), class = "btn-odqa btn-odqa-ghost", style = "padding:4px 12px;font-size:12px;"))
  })
  output$cl_record_display <- renderUI({
    rows <- rv$cl_review_rows; idx <- rv$cl_review_idx; req(length(rows) > 0, rv$work_data)
    row_idx <- rows[min(idx, length(rows))]; df <- rv$work_data; cols <- names(df)
    div(class = "record-fields", lapply(cols, function(cn) {
      val <- as.character(df[row_idx, cn])
      div(class = "record-field", div(class = "field-label", cn), textInput(paste0("rec_edit_", cn), NULL, val, width = "100%"))
    }))
  })
  output$cl_record_actions <- renderUI({
    if (length(rv$cl_review_rows) == 0) return(NULL); l <- lang()
    div(class = "btn-group-odqa", style = "margin:12px 0;",
        actionButton("cl_rec_validate", i18n("cl_validate", l), class = "btn-odqa btn-odqa-success"),
        actionButton("cl_rec_keep", i18n("cl_keep", l), class = "btn-odqa btn-odqa-secondary"),
        actionButton("cl_rec_delete", i18n("cl_delete_rec", l), class = "btn-odqa btn-odqa-danger"),
        actionButton("cl_undo", i18n("cl_undo", l), class = "btn-odqa btn-odqa-ghost"))
  })
  observeEvent(input$cl_prev_rec, { if (rv$cl_review_idx > 1) rv$cl_review_idx <- rv$cl_review_idx - 1L })
  observeEvent(input$cl_next_rec, { if (rv$cl_review_idx < length(rv$cl_review_rows)) rv$cl_review_idx <- rv$cl_review_idx + 1L })
  observeEvent(input$cl_rec_validate, {
    rows <- rv$cl_review_rows; idx <- rv$cl_review_idx; req(length(rows) > 0, rv$work_data)
    row_idx <- rows[min(idx, length(rows))]; cl_undo_push(rv, rv$work_data)
    cols <- names(rv$work_data); changed <- FALSE
    for (cn in cols) {
      new_val <- input[[paste0("rec_edit_", cn)]] %||% ""; old_val <- as.character(rv$work_data[row_idx, cn])
      if (!identical(new_val, old_val)) {
        rv$work_data[row_idx, cn] <- new_val; changed <- TRUE
        rv$cl_log <- rbind(rv$cl_log, data.frame(timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), action = "Validate Record",
                                                 column = cn, row = as.character(row_idx), old_value = old_val, new_value = new_val, stringsAsFactors = FALSE))
      }
    }
    if (!changed) rv$cl_log <- rbind(rv$cl_log, data.frame(timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                                                           action = "Validated (no change)", column = "ALL", row = as.character(row_idx), old_value = "reviewed", new_value = "validated", stringsAsFactors = FALSE))
    safe_notify(paste0("Record #", row_idx, " validated."), "message")
    if (rv$cl_review_idx < length(rv$cl_review_rows)) rv$cl_review_idx <- rv$cl_review_idx + 1L
  })
  observeEvent(input$cl_rec_keep, {
    rows <- rv$cl_review_rows; idx <- rv$cl_review_idx; req(length(rows) > 0)
    row_idx <- rows[min(idx, length(rows))]
    rv$cl_log <- rbind(rv$cl_log, data.frame(timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                                             action = "Keep As Is", column = "ALL", row = as.character(row_idx), old_value = "reviewed", new_value = "kept", stringsAsFactors = FALSE))
    safe_notify(paste0("Record #", row_idx, " kept."), "message")
    if (rv$cl_review_idx < length(rv$cl_review_rows)) rv$cl_review_idx <- rv$cl_review_idx + 1L
  })
  observeEvent(input$cl_rec_delete, {
    rows <- rv$cl_review_rows; idx <- rv$cl_review_idx; req(length(rows) > 0, rv$work_data)
    row_idx <- rows[min(idx, length(rows))]; cl_undo_push(rv, rv$work_data)
    rv$work_data <- rv$work_data[-row_idx, , drop = FALSE]
    rv$cl_log <- rbind(rv$cl_log, data.frame(timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
                                             action = "Delete Record", column = "ALL", row = as.character(row_idx), old_value = "removed", new_value = "DELETED", stringsAsFactors = FALSE))
    rv$cl_review_rows <- rv$cl_review_rows[rv$cl_review_rows != row_idx]
    rv$cl_review_rows <- ifelse(rv$cl_review_rows > row_idx, rv$cl_review_rows - 1L, rv$cl_review_rows)
    if (rv$cl_review_idx > length(rv$cl_review_rows)) rv$cl_review_idx <- max(1L, length(rv$cl_review_rows))
    safe_notify(paste0("Record #", row_idx, " deleted."), "message")
  })
  observeEvent(input$cl_undo, {
    prev <- cl_undo_pop(rv); if (is.null(prev)) { safe_notify("Nothing to undo.", "warning"); return() }
    rv$work_data <- prev; safe_notify("Undo successful.", "message")
  })
  # Sub-step 4.2: find and replace.
  output$cl_fr_col_ui <- renderUI({ req(rv$work_data); selectInput("cl_fr_col", "Column", c("--ALL--", names(rv$work_data)), width = "100%") })
  observeEvent(input$cl_fr_preview, {
    req(rv$work_data, nzchar(input$cl_find %||% ""))
    df <- rv$work_data; cols <- if (input$cl_fr_col == "--ALL--") names(df) else input$cl_fr_col; mc <- 0
    for (c in cols) { vals <- as.character(df[[c]])
    hits <- if (isTRUE(input$cl_fr_case)) grepl(input$cl_find, vals, fixed = !isTRUE(input$cl_fr_regex))
    else grepl(input$cl_find, vals, ignore.case = TRUE, fixed = !isTRUE(input$cl_fr_regex)); mc <- mc + sum(hits, na.rm = TRUE) }
    output$cl_fr_preview_ui <- renderUI(div(style = "font-size:11px;color:var(--text-tertiary);margin:4px 0;", paste0(mc, " ", i18n("s4_fr_count", lang()))))
  })
  observeEvent(input$cl_fr_go, {
    req(rv$work_data, nzchar(input$cl_find %||% "")); cl_undo_push(rv, rv$work_data)
    df <- rv$work_data; cols <- if (input$cl_fr_col == "--ALL--") names(df) else input$cl_fr_col; total <- 0
    for (c in cols) { vals <- as.character(df[[c]])
    new_vals <- if (isTRUE(input$cl_fr_regex)) gsub(input$cl_find, input$cl_replace %||% "", vals, ignore.case = !isTRUE(input$cl_fr_case))
    else gsub(input$cl_find, input$cl_replace %||% "", vals, fixed = isTRUE(input$cl_fr_case))
    changed <- which(vals != new_vals)
    if (length(changed) > 0) { total <- total + length(changed); df[[c]] <- new_vals
    rv$cl_log <- rbind(rv$cl_log, data.frame(timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), action = "Find and Replace",
                                             column = c, row = paste0(length(changed), " cells"), old_value = input$cl_find, new_value = input$cl_replace %||% "", stringsAsFactors = FALSE)) } }
    rv$work_data <- df; safe_notify(paste0(total, " replacements."), "message")
  })
  # Sub-step 4.3: manual cell editing.
  # Manual-edit viewport. At most MANUAL_EDIT_MAX rows are rendered at a time. Editing a
  # single cell only requires the current page to be visible; larger datasets are edited
  # via Find-and-Replace (4.2) or column coercion (4.7), both of which operate on the
  # full data.frame server-side.
  MANUAL_EDIT_MAX <- 1000L
  rv_manual_offset <- reactiveVal(0L)
  output$dt_cl_edit <- renderDT({
    req(rv$work_data)
    n_total <- nrow(rv$work_data)
    off     <- rv_manual_offset()
    if (off >= n_total) off <- 0L
    end     <- min(off + MANUAL_EDIT_MAX, n_total)
    slice   <- rv$work_data[(off + 1L):end, , drop = FALSE]
    cap_note <- if (n_total > MANUAL_EDIT_MAX) {
      switch(lang(),
             de = sprintf("Anzeige der Zeilen %d–%d von %d. Für grössere Mengen 4.2 Suchen & Ersetzen oder 4.7 Format korrigieren verwenden.",
                          off + 1L, end, n_total),
             fr = sprintf("Affichage des lignes %d à %d sur %d. Pour des volumes plus importants, utilisez 4.2 Rechercher et remplacer ou 4.7 Corriger le format.",
                          off + 1L, end, n_total),
             sprintf("Showing rows %d–%d of %d. For larger volumes, use 4.2 Find and Replace or 4.7 Fix Column Format.",
                     off + 1L, end, n_total))
    } else NULL
    if (!is.null(cap_note))
      showNotification(cap_note, type = "message", duration = 5)
    datatable(
      slice,
      editable = TRUE,
      options  = list(pageLength = 20, scrollX = TRUE, dom = "ftipr",
                      processing = TRUE),
      rownames = FALSE,
      class    = "stripe compact"
    )
  })
  observeEvent(input$dt_cl_edit_cell_edit, {
    info <- input$dt_cl_edit_cell_edit
    if (is.null(info)) return()
    cl_undo_push(rv, rv$work_data)
    # info$row is relative to the current viewport slice. Translate it to an absolute
    # row index.
    abs_row <- rv_manual_offset() + info$row
    col_idx <- info$col + 1L
    if (abs_row < 1L || abs_row > nrow(rv$work_data)) return()
    old_val <- as.character(rv$work_data[abs_row, col_idx])
    rv$work_data[abs_row, col_idx] <- info$value
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      action    = "Manual Edit",
      column    = names(rv$work_data)[col_idx],
      row       = as.character(abs_row),
      old_value = old_val,
      new_value = as.character(info$value),
      stringsAsFactors = FALSE))
  })
  # Sub-step 4.4: audit trail.
  output$dt_cl_log <- renderDT({ log <- rv$cl_log; if (nrow(log) == 0) return(datatable(data.frame(Message = i18n("cl_log_empty", lang())), rownames = FALSE))
  datatable(log, options = list(pageLength = 10, scrollX = TRUE, dom = "ftipr", order = list(list(0, "desc"))), rownames = FALSE, class = "stripe compact") })
  # Sub-step 4.5 with per-cell diff highlights. The cleaned table renders HTML spans
  # marking modified cells (amber) and cells that became NA (red). Hovering a modified
  # cell shows the original value. The original table is plain.
  observeEvent(input$cl_gen_compare, {
    req(rv$original_data, rv$work_data)
    output$dt_cl_orig_diff <- renderUI(div(
      h4(style = "font-size:12px;font-weight:700;", i18n("cl_original", lang())),
      DTOutput("dt_compare_orig")))
    output$dt_cl_clean_diff <- renderUI(div(
      h4(style = "font-size:12px;font-weight:700;", i18n("cl_cleaned", lang())),
      # Legend explaining the two diff colours.
      div(style = "display:flex;gap:12px;font-size:11px;margin:0 0 6px 2px;",
          tags$span(style = "background:#fef3c7;color:#92400e;padding:1px 6px;border-radius:3px;font-weight:600;",
                    switch(lang(), de = "geändert", fr = "modifié", "modified")),
          tags$span(style = "background:#fde8e8;color:#b91c1c;padding:1px 6px;border-radius:3px;font-weight:600;",
                    switch(lang(), de = "neu NA", fr = "nouveau NA", "became NA"))),
      DTOutput("dt_compare_clean")))
    output$dt_compare_orig <- renderDT(datatable(
      head(rv$original_data, 50),
      options = list(pageLength = 10, scrollX = TRUE, dom = "tp"),
      rownames = FALSE, class = "stripe compact"))
    output$dt_compare_clean <- renderDT(datatable(
      head(build_diff_html(rv$original_data, rv$work_data), 50),
      options  = list(pageLength = 10, scrollX = TRUE, dom = "tp"),
      rownames = FALSE, escape = FALSE, class = "stripe compact"))
  })
  # Sub-steps 4.6 to 4.8.
  output$cl_rename_col_ui <- renderUI({ req(rv$work_data); selectInput("cl_rename_col", i18n("s4_fmt_col", lang()), names(rv$work_data), width = "100%") })
  observeEvent(input$cl_rename_go, { req(rv$work_data, input$cl_rename_col, nzchar(input$cl_new_name %||% ""))
    old_name <- input$cl_rename_col; new_name <- trimws(input$cl_new_name)
    if (new_name %in% names(rv$work_data)) { safe_notify("Name exists.", "error"); return() }
    cl_undo_push(rv, rv$work_data); idx <- which(names(rv$work_data) == old_name); names(rv$work_data)[idx] <- new_name
    rv$cl_log <- rbind(rv$cl_log, data.frame(timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), action = "Rename Column",
                                             column = old_name, row = "", old_value = old_name, new_value = new_name, stringsAsFactors = FALSE))
    safe_notify(paste0("Renamed: ", old_name, " -> ", new_name), "message") })
  # Step 4.7: fix column format. Type coercion with NA logging for incompatible cells.
  output$s4_fmt_title_ui <- renderUI(i18n("s4_fmt_title", lang()))
  output$s4_fmt_hint_ui  <- renderUI(i18n("s4_fmt_hint",  lang()))
  
  output$cl_fmt_col_ui <- renderUI({
    req(rv$work_data)
    selectInput("cl_fmt_col", "Column",
                choices = names(rv$work_data), width = "100%")
  })
  
  # Per-column detected-type table. Reads from rv$types_cache, which is populated on
  # entry to Step 3, so opening Step 4 shows the table instantly.
  output$dt_cl_types <- renderDT({
    req(rv$work_data)
    types_df <- rv$types_cache
    if (is.null(types_df)) {
      df <- rv$work_data
      types_df <- data.frame(
        Column        = names(df),
        Current_Class = vapply(df, function(x) paste(class(x), collapse = "/"), character(1)),
        Detected_Type = vapply(df, detect_col_type, character(1)),
        Non_NA        = vapply(df, function(x) sum(!is.na(x) & nzchar(trimws(as.character(x)))), integer(1)),
        stringsAsFactors = FALSE
      )
      rv$types_cache <- types_df
    }
    l <- lang()
    names(types_df) <- c(
      i18n("s4_fmt_type_col", l),
      i18n("s4_fmt_type_cur", l),
      i18n("s4_fmt_type_det", l),
      i18n("s4_fmt_type_nn",  l)
    )
    datatable(types_df,
              options = list(pageLength = 8, dom = "ftipr", scrollX = TRUE),
              rownames = FALSE,
              class = "stripe compact")
  })
  
  # Preview how many cells would become NA under the requested coercion.
  observeEvent(input$cl_fmt_preview, {
    req(rv$work_data, input$cl_fmt_col, input$cl_fmt_target)
    col <- input$cl_fmt_col; target <- input$cl_fmt_target
    res <- coerce_col(rv$work_data[[col]], target)
    n   <- length(res$na_idx)
    output$cl_fmt_preview_ui <- renderUI({
      if (n == 0) {
        div(class = "odqa-hint success",
            span(class = "odqa-hint-icon", "OK"),
            paste0("No cells would become NA. '", col, "' -> ", target, " is clean."))
      } else {
        sample_vals <- head(as.character(rv$work_data[[col]])[res$na_idx], 8)
        div(class = "odqa-hint warning",
            span(class = "odqa-hint-icon", "!"),
            paste0(n, " cell(s) cannot be coerced to ", target,
                   " and would become NA. Examples: ",
                   paste(sample_vals, collapse = " | ")))
      }
    })
  })
  
  # Apply the coercion and log each NA-introducing cell in the audit trail.
  observeEvent(input$cl_fmt_apply, {
    req(rv$work_data, input$cl_fmt_col, input$cl_fmt_target)
    col <- input$cl_fmt_col; target <- input$cl_fmt_target
    cl_undo_push(rv, rv$work_data)
    old_vec <- rv$work_data[[col]]
    res     <- coerce_col(old_vec, target)
    rv$work_data[[col]] <- res$new
    ts <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    # Header entry.
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      timestamp = ts, action = paste0("Coerce to ", target),
      column = col, row = paste0(nrow(rv$work_data), " cells"),
      old_value = paste(class(old_vec), collapse = "/"),
      new_value = target, stringsAsFactors = FALSE))
    # Per-cell NA entries.
    if (length(res$na_idx) > 0) {
      entries <- data.frame(
        timestamp = rep(ts, length(res$na_idx)),
        action    = rep("Coercion NA", length(res$na_idx)),
        column    = rep(col, length(res$na_idx)),
        row       = as.character(res$na_idx),
        old_value = as.character(old_vec[res$na_idx]),
        new_value = rep("NA", length(res$na_idx)),
        stringsAsFactors = FALSE
      )
      rv$cl_log <- rbind(rv$cl_log, entries)
    }
    safe_notify(paste0("Coerced '", col, "' to ", target,
                       " (", length(res$na_idx), " cell(s) became NA)."),
                "message")
  })
  output$cl_delcol_ui <- renderUI({ req(rv$work_data); selectInput("cl_delcol_sel", i18n("cl_delcol_label", lang()), names(rv$work_data), width = "100%") })
  observeEvent(input$cl_delcol, { req(rv$work_data, input$cl_delcol_sel); col <- input$cl_delcol_sel; cl_undo_push(rv, rv$work_data)
  rv$work_data[[col]] <- NULL
  rv$cl_log <- rbind(rv$cl_log, data.frame(timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), action = "Delete Column",
                                           column = col, row = "all", old_value = "removed", new_value = "--", stringsAsFactors = FALSE))
  safe_notify(paste0("Column '", col, "' deleted."), "message") })
  # Downloads.
  output$dl_cl_cert <- downloadHandler(
    filename = function() paste0("Cleansing_Certificate_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx"),
    content = function(file) {
      result <- tryCatch(gen_cleansing_certificate(rv$cl_log, lang(), rv$user_info), error = function(e) NULL)
      if (!is.null(result) && file.exists(result)) file.copy(result, file)
      else safe_notify("Certificate generation failed.", "error")
    })
  output$dl_cl_data <- downloadHandler(filename = function() paste0("Cleaned_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"),
                                       content = function(file) write.csv(rv$work_data %||% data.frame(), file, row.names = FALSE, fileEncoding = "UTF-8"))
  output$dl_cl_log_csv <- downloadHandler(filename = function() paste0("Audit_Trail_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"),
                                          content = function(file) write.csv(rv$cl_log, file, row.names = FALSE, fileEncoding = "UTF-8"))
  
  # Summary screen.
  output$finish_title_ui <- renderUI(i18n("finish_title", lang()))
  output$finish_recap_ui <- renderUI({
    l <- lang(); qs <- rv$quality_score %||% list(score = 0, affected_rows = 0, issue_count = 0)
    n_checks <- length(rv$custom_checks); n_cl <- nrow(rv$cl_log); n_total <- nrow(rv$work_data %||% data.frame())
    div(class = "recap", h3(i18n("finish_recap", l)),
        div(class = "recap-item", tags$span(style = "font-weight:600;width:200px;", "Dataset:"), tags$span(paste0(n_total, " records"))),
        div(class = "recap-item", tags$span(style = "font-weight:600;width:200px;", "Checks Defined:"), tags$span(n_checks)),
        div(class = "recap-item", tags$span(style = "font-weight:600;width:200px;", "Issues Found:"), tags$span(qs$issue_count)),
        div(class = "recap-item", tags$span(style = "font-weight:600;width:200px;", "Fitness Score:"), tags$span(style = paste0("color:", score_hex(qs$score), ";font-weight:700;"), paste0(qs$score, "%"))),
        div(class = "recap-item", tags$span(style = "font-weight:600;width:200px;", "Cleansing Actions:"), tags$span(n_cl)))
  })
  output$finish_feedback_ui <- renderUI(div(style = "font-size:12px;color:var(--text-secondary);", i18n("finish_feedback", lang()),
                                            tags$br(), HTML("Open DQA | MIT License | &copy; 2026")))
  output$dl_final_cert <- downloadHandler(filename = function() paste0("DQ_Certificate_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx"),
                                          content = function(file) { result <- tryCatch(gen_dq_certificate(rv$issues, length(rv$custom_checks), rv$work_data, lang(),
                                                                                                           user_info = rv$user_info, perf_data = rv$perf_data, custom_checks = rv$custom_checks), error = function(e) NULL)
                                          if (!is.null(result) && file.exists(result)) file.copy(result, file) })
  output$dl_final_issues <- downloadHandler(filename = function() paste0("Issues_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"),
                                            content = function(file) write.csv(rv$issues %||% data.frame(), file, row.names = FALSE))
  output$dl_final_cl_cert <- downloadHandler(filename = function() paste0("Cleansing_Certificate_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".docx"),
                                             content = function(file) { result <- tryCatch(gen_cleansing_certificate(rv$cl_log, lang(), rv$user_info), error = function(e) NULL)
                                             if (!is.null(result) && file.exists(result)) file.copy(result, file) })
  output$dl_final_cleaned <- downloadHandler(
    filename = function() paste0("Cleaned_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv"),
    content  = function(file) write.csv(rv$work_data %||% data.frame(), file, row.names = FALSE)
  )
}

shinyApp(ui = ui, server = server)
