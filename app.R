###############################################################################
# Open DQA V1.0 – Data Quality Assessment & Cleansing Platform
# Authors: G. Kamdje Wabo, P. Sokolowski, T. Ganslandt, F. Siegel – MIISM
# License: MIT | © 2026 Heidelberg University
# Repository: ####
#
# This is an open-source research tool for systematic clinical data quality
# assessment. NOT a medical device (see disclaimer).
#
# V.0.1:
#   - Stability hardening (tryCatch everywhere, chunked processing)
#   - Performance timing for imports, checks, and all tasks
#   - Dynamic check constraints: is_not.na, not_contains, BETWEEN,
#     NOT BETWEEN, IN(), NOT IN(), REGEXP
#   - Assistant for checks and data cleansing (cluster-based)
#   - Enhanced reports with detailed check info, metrics, plots
#   - Self-learning performance optimization
###############################################################################
pkgs <- c(
  "shiny", "bs4Dash", "DT", "readxl", "jsonlite", "stringr", "dplyr",
  "lubridate", "rlang", "data.table", "shinyjs", "shinyWidgets", "waiter",
  "officer", "flextable", "plogr", "cluster", "emayili", "DBI","RPostgres"
)

to_install <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(to_install) > 0) {
  for (pkg in to_install) {
    tryCatch(install.packages(pkg, dependencies = TRUE, quiet = TRUE),
             error = function(e) message(paste("Optional:", pkg, "not installed")))
  }
}


# ── Section 1: Libraries ─────────────────────────────────────────────────────
suppressPackageStartupMessages({
  library(shiny); library(bs4Dash); library(DT); library(readxl)
  library(jsonlite); library(stringr); library(dplyr); library(lubridate)
  library(rlang); library(stats); library(data.table); library(shinyjs)
  library(shinyWidgets); library(waiter); library(officer); library(flextable)
  library(plogr)
})
has_cluster <- tryCatch(requireNamespace("cluster", quietly = TRUE), error = function(e) FALSE)
if (has_cluster) library(cluster)
has_emayili <- tryCatch(requireNamespace("emayili", quietly = TRUE), error = function(e) FALSE)

# Optional SQL libraries
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

# Configuration: allow uploads up to 2 GB, sanitize errors
options(shiny.maxRequestSize = 2 * 1024^3, shiny.sanitize.errors = TRUE)

# ── i18n helper: current language code (EN/DE/FR) ────────────────────────────
L <- function(default = "en") {
  # Works both:
  #  - during UI construction (no reactive domain yet)
  #  - inside server reactives/observers (reactive domain exists)
  s <- tryCatch(shiny::getDefaultReactiveDomain(), error = function(e) NULL)
  
  lang <- NULL
  if (!is.null(s)) {
    lang <- tryCatch(s$input$lang, error = function(e) NULL)
  }
  
  if (is.null(lang) || is.na(lang) || !nzchar(as.character(lang))) {
    default
  } else {
    as.character(lang)
  }
}



# ── Section 2: Internationalisation (i18n) ───────────────────────────────────
# Key/value store for EN/DE/FR UI strings. Each key maps to a named list of
# translations. The helper i18n(key, lang) retrieves the correct string.

I18N <- list(
  # ── App-level ──────────────────────────────────────────────────────────────
  app_title     = list(en = "Open DQA", de = "Open DQA", fr = "Open DQA"),
  app_version   = list(en = "V0.1", de = "V0.1", fr = "V0.1"),
  
  # ── Welcome page ──────────────────────────────────────────────────────────
  wel_title = list(
    en = "Welcome to Open DQA",
    de = "Willkommen bei Open DQA",
    fr = "Bienvenue dans Open DQA"
  ),
  wel_sub = list(
    en = "Intuitive data quality assessment for clinical research",
    de = "Intuitive Datenqualit\u00e4tsbewertung f\u00fcr klinische Forschung",
    fr = "\u00c9valuation intuitive de la qualit\u00e9 des donn\u00e9es pour la recherche clinique"
  ),
  wel_desc = list(
    en = "Open DQA systematically assesses and improves the quality of clinical datasets through a fitness-for-purpose approach: your data quality is evaluated against the specific requirements of your research question. It provides 77 built-in plausibility checks, a flexible custom rule builder for domain-specific fitness-for-purpose assessments, guided data cleansing with a full audit trail, and publication-ready reports \u2013 all in a transparent, reproducible workflow.",
    de = "Open DQA bewertet und verbessert systematisch die Qualit\u00e4t klinischer Datens\u00e4tze durch einen Fitness-for-Purpose-Ansatz: Ihre Datenqualit\u00e4t wird gegen die spezifischen Anforderungen Ihrer Forschungsfrage bewertet. Es bietet 77 integrierte Plausibilit\u00e4tspr\u00fcfungen, einen flexiblen Regelgenerator f\u00fcr dom\u00e4nenspezifische Fitness-for-Purpose-Bewertungen, gef\u00fchrte Datenbereinigung mit vollst\u00e4ndigem Audit-Trail und publikationsfertige Berichte \u2013 alles in einem transparenten, reproduzierbaren Workflow.",
    fr = "Open DQA \u00e9value et am\u00e9liore syst\u00e9matiquement la qualit\u00e9 des jeux de donn\u00e9es cliniques par une approche fitness-for-purpose : la qualit\u00e9 de vos donn\u00e9es est \u00e9valu\u00e9e par rapport aux exigences sp\u00e9cifiques de votre question de recherche. Il propose 77 v\u00e9rifications de plausibilit\u00e9 int\u00e9gr\u00e9es, un constructeur de r\u00e8gles flexible pour des \u00e9valuations fitness-for-purpose sp\u00e9cifiques au domaine, un nettoyage guid\u00e9 avec piste d\u2019audit compl\u00e8te et des rapports pr\u00eats pour la publication \u2013 le tout dans un workflow transparent et reproductible."
  ),
  wel_tut = list(en = "Take the Tutorial", de = "Tutorial starten", fr = "Suivre le tutoriel"),
  wel_tut_hint = list(
    en = "New here? This step-by-step guide walks you through every feature with concrete examples so you can start productively right away.",
    de = "Erste Nutzung? Diese Schritt-f\u00fcr-Schritt-Anleitung erkl\u00e4rt jede Funktion mit konkreten Beispielen, damit Sie sofort produktiv starten k\u00f6nnen.",
    fr = "Premi\u00e8re utilisation ? Ce guide pas \u00e0 pas vous pr\u00e9sente chaque fonctionnalit\u00e9 avec des exemples concrets pour d\u00e9marrer imm\u00e9diatement."
  ),
  wel_start = list(en = "Proceed to Assessment", de = "Zur Bewertung", fr = "Acc\u00e9der \u00e0 l\u2019\u00e9valuation"),
  wel_start_hint = list(
    en = "Load your dataset and begin the structured quality assessment workflow.",
    de = "Laden Sie Ihren Datensatz und starten Sie den strukturierten Qualit\u00e4tsbewertungs-Workflow.",
    fr = "Chargez votre jeu de donn\u00e9es et lancez le workflow d\u2019\u00e9valuation structur\u00e9."
  ),
  wel_workflow_title = list(en = "How It Works", de = "So funktioniert es", fr = "Comment \u00e7a marche"),
  wel_who_title = list(en = "Who Is This For?", de = "F\u00fcr wen ist das?", fr = "\u00c0 qui s\u2019adresse cet outil ?"),
  wel_who = list(
    en = "Researchers, data managers, clinical study coordinators, hospital IT, and quality officers who need a transparent, reproducible, and fully documented quality assessment workflow for their clinical data.",
    de = "Forscher, Datenmanager, klinische Studienkoordinatoren, Krankenhaus-IT und Qualit\u00e4tsbeauftragte, die einen transparenten, reproduzierbaren und vollst\u00e4ndig dokumentierten Qualit\u00e4tsbewertungs-Workflow f\u00fcr ihre klinischen Daten ben\u00f6tigen.",
    fr = "Chercheurs, gestionnaires de donn\u00e9es, coordinateurs d\u2019\u00e9tudes cliniques, informaticiens hospitaliers et responsables qualit\u00e9 qui ont besoin d\u2019un workflow d\u2019\u00e9valuation de qualit\u00e9 transparent, reproductible et enti\u00e8rement document\u00e9."
  ),
  wel_faq_title = list(en = "Frequently Asked Questions", de = "H\u00e4ufig gestellte Fragen", fr = "Questions fr\u00e9quentes"),
  
  # ── Feature cards ──────────────────────────────────────────────────────────
  feat_import   = list(en = "Multi-Format Import", de = "Multi-Format-Import", fr = "Import multi-format"),
  feat_import_d = list(en = "CSV \u00b7 Excel \u00b7 JSON \u00b7 FHIR \u00b7 SQL", de = "CSV \u00b7 Excel \u00b7 JSON \u00b7 FHIR \u00b7 SQL", fr = "CSV \u00b7 Excel \u00b7 JSON \u00b7 FHIR \u00b7 SQL"),
  feat_checks   = list(en = "77 Built-in Checks", de = "77 integrierte Pr\u00fcfungen", fr = "77 v\u00e9rifications int\u00e9gr\u00e9es"),
  feat_checks_d = list(en = "Completeness, plausibility, temporal & code integrity", de = "Vollst\u00e4ndigkeit, Plausibilit\u00e4t, zeitlich & Code-Integrit\u00e4t", fr = "Compl\u00e9tude, plausibilit\u00e9, temporelle & int\u00e9grit\u00e9 des codes"),
  feat_builder  = list(en = "Custom Rule Builder", de = "Eigener Regelgenerator", fr = "Constructeur de r\u00e8gles"),
  feat_builder_d= list(en = "Define your own checks for any data standard", de = "Eigene Pr\u00fcfungen f\u00fcr jeden Datenstandard", fr = "D\u00e9finissez vos propres v\u00e9rifications"),
  feat_report   = list(en = "Publication Reports", de = "Publikationsberichte", fr = "Rapports de publication"),
  feat_report_d = list(en = "Word & CSV with charts for papers & audits", de = "Word & CSV mit Grafiken f\u00fcr Paper & Audits", fr = "Word & CSV avec graphiques pour publications"),
  feat_cleanse  = list(en = "Guided Cleansing", de = "Gef\u00fchrte Bereinigung", fr = "Nettoyage guid\u00e9"),
  feat_cleanse_d= list(en = "Step-by-step with full audit trail", de = "Schritt f\u00fcr Schritt mit Audit-Trail", fr = "\u00c9tape par \u00e9tape avec piste d\u2019audit"),
  feat_lang     = list(en = "Trilingual UI", de = "Dreisprachige UI", fr = "Interface trilingue"),
  feat_lang_d   = list(en = "English \u00b7 German \u00b7 French", de = "Englisch \u00b7 Deutsch \u00b7 Franz\u00f6sisch", fr = "Anglais \u00b7 Allemand \u00b7 Fran\u00e7ais"),
  
  # ── Disclaimer ─────────────────────────────────────────────────────────────
  disclaimer_title = list(
    en = "\u26A0\uFE0F Important Notice \u2013 Research Tool",
    de = "\u26A0\uFE0F Wichtiger Hinweis \u2013 Forschungstool",
    fr = "\u26A0\uFE0F Avis important \u2013 Outil de recherche"
  ),
  disclaimer_text = list(
    en = "Open DQA is an open-source research tool developed at Heidelberg University (MIISM). It is NOT a certified medical product under EU MDR, FDA, or any regulatory framework, and must not be used as a basis for clinical decisions.\n\nHowever, Open DQA is specifically designed to support clinical research by providing transparent, reproducible, and auditable data quality assessment. Researchers are strongly encouraged to integrate Open DQA into their data management workflows to strengthen the reliability and credibility of their study results.\n\nThe user is solely responsible for validating and interpreting all results.",
    de = "Open DQA ist ein Open-Source-Forschungstool, entwickelt an der Universit\u00e4t Heidelberg (MIISM). Es ist KEIN zertifiziertes Medizinprodukt gem\u00e4\u00df EU-MDR, FDA oder einem anderen Rahmen und darf nicht als Grundlage f\u00fcr klinische Entscheidungen dienen.\n\nOpen DQA wurde jedoch speziell entwickelt, um klinische Forschung zu unterst\u00fctzen, indem es transparente, reproduzierbare und \u00fcberpr\u00fcfbare Datenqualit\u00e4tsbewertungen erm\u00f6glicht. Forscher sind ausdr\u00fccklich ermutigt, Open DQA in ihre Datenmanagement-Workflows zu integrieren.\n\nDer Nutzer ist allein verantwortlich f\u00fcr die Validierung und Interpretation aller Ergebnisse.",
    fr = "Open DQA est un outil de recherche open source d\u00e9velopp\u00e9 \u00e0 l\u2019Universit\u00e9 de Heidelberg (MIISM). Ce n\u2019est PAS un produit m\u00e9dical certifi\u00e9 selon le MDR, la FDA ou tout cadre r\u00e9glementaire, et ne doit pas servir de base \u00e0 des d\u00e9cisions cliniques.\n\nCependant, Open DQA est sp\u00e9cifiquement con\u00e7u pour soutenir la recherche clinique en fournissant une \u00e9valuation de la qualit\u00e9 des donn\u00e9es transparente, reproductible et auditable. Les chercheurs sont vivement encourag\u00e9s \u00e0 int\u00e9grer Open DQA dans leurs workflows.\n\nL\u2019utilisateur est seul responsable de la validation et de l\u2019interpr\u00e9tation de tous les r\u00e9sultats."
  ),
  disclaimer_accept = list(
    en = "I have read and accept this notice \u2013 I will use this tool for research purposes",
    de = "Ich habe diesen Hinweis gelesen und akzeptiere ihn \u2013 Ich verwende dieses Tool f\u00fcr Forschungszwecke",
    fr = "J\u2019ai lu et j\u2019accepte cet avis \u2013 J\u2019utiliserai cet outil \u00e0 des fins de recherche"
  ),
  disclaimer_proceed = list(en = "Enter Open DQA", de = "Open DQA starten", fr = "Entrer dans Open DQA"),
  
  # ── Navigation & buttons ───────────────────────────────────────────────────
  btn_back  = list(en = "Back", de = "Zur\u00fcck", fr = "Retour"),
  btn_next  = list(en = "Next", de = "Weiter", fr = "Suivant"),
  btn_home  = list(en = "Home", de = "Start", fr = "Accueil"),
  btn_load  = list(en = "Load Data", de = "Daten laden", fr = "Charger"),
  btn_save  = list(en = "Save & Continue", de = "Speichern & Weiter", fr = "Enregistrer & Continuer"),
  btn_run   = list(en = "Run All Checks", de = "Alle Pr\u00fcfungen starten", fr = "Lancer toutes les v\u00e9rifications"),
  btn_selall= list(en = "Select All", de = "Alle w\u00e4hlen", fr = "Tout s\u00e9lectionner"),
  btn_desel = list(en = "Deselect All", de = "Alle abw\u00e4hlen", fr = "Tout d\u00e9s\u00e9lectionner"),
  btn_test  = list(en = "Test Connection", de = "Verbindung testen", fr = "Tester la connexion"),
  btn_sql   = list(en = "Run Query", de = "Abfrage ausf\u00fchren", fr = "Ex\u00e9cuter"),
  btn_finish= list(en = "Finish & Summary", de = "Abschlie\u00dfen & Zusammenfassung", fr = "Terminer & R\u00e9sum\u00e9"),
  nav_refresh  = list(en = "Reset All", de = "Alles zur\u00fccksetzen", fr = "Tout r\u00e9initialiser"),
  nav_tutorial = list(en = "Tutorial", de = "Tutorial", fr = "Tutoriel"),
  nav_home_btn = list(en = "Home", de = "Start", fr = "Accueil"),
  confirm_reset = list(
    en = "This will clear ALL data, mappings, checks, and results. Are you sure?",
    de = "Dies l\u00f6scht ALLE Daten, Zuordnungen, Pr\u00fcfungen und Ergebnisse. Sind Sie sicher?",
    fr = "Cela supprimera TOUTES les donn\u00e9es. \u00cates-vous s\u00fbr ?"
  ),
  no_data    = list(en = "No data loaded yet.", de = "Keine Daten geladen.", fr = "Aucune donn\u00e9e charg\u00e9e."),
  no_issues  = list(en = "No issues found!", de = "Keine Probleme!", fr = "Aucun probl\u00e8me !"),
  loading    = list(en = "Analyzing\u2026", de = "Analysiere\u2026", fr = "Analyse en cours\u2026"),
  
  # ── Step 1: Load ───────────────────────────────────────────────────────────
  s1_title   = list(en = "Step 1 \u2013 Load Your Dataset", de = "Schritt 1 \u2013 Datensatz laden", fr = "\u00c9tape 1 \u2013 Charger le jeu de donn\u00e9es"),
  s1_preview = list(en = "Data Preview", de = "Datenvorschau", fr = "Aper\u00e7u des donn\u00e9es"),
  s1_source  = list(
    en = "Where is your data? Choose your source and format below.",
    de = "Wo befinden sich Ihre Daten? W\u00e4hlen Sie Quelle und Format.",
    fr = "O\u00f9 sont vos donn\u00e9es ? Choisissez la source et le format."
  ),
  s1_local   = list(en = "Local File Upload", de = "Lokale Datei hochladen", fr = "Fichier local"),
  s1_db      = list(en = "SQL Database", de = "SQL-Datenbank", fr = "Base de donn\u00e9es SQL"),
  s1_fhir_srv= list(en = "FHIR Server", de = "FHIR-Server", fr = "Serveur FHIR"),
  
  # ── Step 2: Map ────────────────────────────────────────────────────────────
  s2_title   = list(en = "Step 2 \u2013 Map Your Columns", de = "Schritt 2 \u2013 Spalten zuordnen", fr = "\u00c9tape 2 \u2013 Mapper vos colonnes"),
  s2_info    = list(
    en = "Tell Open DQA which columns correspond to standard fields. Auto-detection has pre-filled likely matches \u2013 verify and adjust as needed.",
    de = "Teilen Sie Open DQA mit, welche Spalten den Standardfeldern entsprechen. Die Auto-Erkennung hat wahrscheinliche Zuordnungen vorausgef\u00fcllt \u2013 pr\u00fcfen und anpassen.",
    fr = "Indiquez \u00e0 Open DQA quelles colonnes correspondent aux champs standard. La d\u00e9tection automatique a pr\u00e9-rempli les correspondances probables \u2013 v\u00e9rifiez et ajustez."
  ),
  s2_gender  = list(en = "Gender Value Standardisation", de = "Geschlechts-Standardisierung", fr = "Standardisation du genre"),
  s2_gender_why = list(
    en = "Clinical datasets encode gender in many ways (m/f, 1/2, Mann/Frau, male/female\u2026). Open DQA needs to know which values represent \u2018male\u2019 and which represent \u2018female\u2019 so that gender-specific plausibility checks (e.g., pregnancy codes for male patients) work correctly. List all values separated by commas.",
    de = "Klinische Datens\u00e4tze kodieren Geschlecht unterschiedlich (m/f, 1/2, Mann/Frau\u2026). Open DQA muss wissen, welche Werte \u2018m\u00e4nnlich\u2019 und welche \u2018weiblich\u2019 bedeuten, damit geschlechtsspezifische Plausibilit\u00e4tspr\u00fcfungen korrekt funktionieren. Listen Sie alle Werte durch Komma getrennt auf.",
    fr = "Les jeux de donn\u00e9es cliniques encodent le genre de multiples fa\u00e7ons (m/f, 1/2, homme/femme\u2026). Open DQA doit savoir quelles valeurs repr\u00e9sentent \u2018masculin\u2019 et \u2018f\u00e9minin\u2019 pour que les v\u00e9rifications de plausibilit\u00e9 li\u00e9es au genre fonctionnent correctement. Listez toutes les valeurs s\u00e9par\u00e9es par des virgules."
  ),
  
  # ── Step 3: Built-in Checks ────────────────────────────────────────────────
  s3_title   = list(en = "Step 3 \u2013 Select Built-in Checks", de = "Schritt 3 \u2013 Standardpr\u00fcfungen w\u00e4hlen", fr = "\u00c9tape 3 \u2013 V\u00e9rifications int\u00e9gr\u00e9es"),
  s3_info    = list(
    en = "77 built-in checks in 6 categories. Checks that can run with your mapped columns are highlighted in colour; unavailable checks are greyed out. Select those relevant to your study. Many checks work with any ICD-10 variant; some are specific to the German Modification (GM).",
    de = "77 integrierte Pr\u00fcfungen in 6 Kategorien. Pr\u00fcfungen, die mit Ihren zugeordneten Spalten laufen k\u00f6nnen, sind farblich hervorgehoben; nicht verf\u00fcgbare sind ausgegraut. Viele Pr\u00fcfungen funktionieren mit jeder ICD-10-Variante; einige sind spezifisch f\u00fcr die Deutsche Modifikation (GM).",
    fr = "77 v\u00e9rifications en 6 cat\u00e9gories. Celles ex\u00e9cutables avec vos colonnes sont color\u00e9es ; les indisponibles sont gris\u00e9es. Beaucoup fonctionnent avec toute variante CIM-10 ; certaines sont sp\u00e9cifiques \u00e0 la GM."
  ),
  
  # ── Step 4: Custom Checks ──────────────────────────────────────────────────
  s4_title   = list(en = "Step 4 \u2013 Build Custom Checks", de = "Schritt 4 \u2013 Eigene Pr\u00fcfungen", fr = "\u00c9tape 4 \u2013 V\u00e9rifications personnalis\u00e9es"),
  s4_info    = list(
    en = "This is where you build fitness-for-purpose assessment checks \u2013 custom rules tailored to YOUR specific research question. The 77 built-in checks cover universal plausibility; here you define what \u2018quality\u2019 means for YOUR study. Need additional checks not covered by the built-in rules? Build your own in 3 steps. Essential for any non-standard coding system or study-specific validation. Import/export as JSON for reuse across projects.",
    de = "Hier erstellen Sie Fitness-for-Purpose-Pr\u00fcfungen \u2013 ma\u00dfgeschneiderte Regeln f\u00fcr IHRE spezifische Forschungsfrage. Die 77 integrierten Checks decken universelle Plausibilit\u00e4t ab; hier definieren Sie, was \u2018Qualit\u00e4t\u2019 f\u00fcr IHRE Studie bedeutet. Zus\u00e4tzliche Pr\u00fcfungen ben\u00f6tigt? Erstellen Sie eigene in 3 Schritten. Essentiell f\u00fcr nicht-standardisierte Codiersysteme oder studienspezifische Validierung. Import/Export als JSON zur Wiederverwendung.",
    fr = "C\u2019est ici que vous construisez des v\u00e9rifications fitness-for-purpose \u2013 des r\u00e8gles adapt\u00e9es \u00e0 VOTRE question de recherche sp\u00e9cifique. Les 77 v\u00e9rifications int\u00e9gr\u00e9es couvrent la plausibilit\u00e9 universelle ; ici vous d\u00e9finissez ce que \u2018qualit\u00e9\u2019 signifie pour VOTRE \u00e9tude. Besoin de v\u00e9rifications suppl\u00e9mentaires ? Cr\u00e9ez-les en 3 \u00e9tapes. Import/export JSON pour r\u00e9utilisation."
  ),
  s4_a       = list(en = "A \u2013 Define Conditions", de = "A \u2013 Bedingungen definieren", fr = "A \u2013 D\u00e9finir les conditions"),
  s4_a_hint  = list(
    en = "Why: Select which data values should be flagged. First choose comparison type: compare a column against a fixed value, OR compare two columns against each other. You can mix both types with AND/OR logic.",
    de = "Warum: W\u00e4hlen Sie, welche Datenwerte markiert werden sollen. Zuerst Vergleichstyp w\u00e4hlen: Spalte gegen festen Wert ODER zwei Spalten gegeneinander. Beide Typen k\u00f6nnen mit AND/OR kombiniert werden.",
    fr = "Pourquoi : S\u00e9lectionnez les valeurs \u00e0 signaler. Choisissez d\u2019abord le type de comparaison : colonne vs valeur fixe OU colonne vs colonne. Les deux types peuvent \u00eatre combin\u00e9s avec AND/OR."
  ),
  s4_b       = list(en = "B \u2013 Generate R Query", de = "B \u2013 R-Abfrage generieren", fr = "B \u2013 G\u00e9n\u00e9rer la requ\u00eate R"),
  s4_b_hint  = list(
    en = "Why: The R expression is the executable logic. Click \u2018Generate\u2019 to auto-create it from your conditions, then review. Example: (age > 120) flags impossible ages.",
    de = "Warum: Der R-Ausdruck ist die ausf\u00fchrbare Logik. Klicken Sie \u2018Generieren\u2019 und pr\u00fcfen Sie. Beispiel: (age > 120) markiert unm\u00f6gliche Alter.",
    fr = "Pourquoi : L\u2019expression R est la logique ex\u00e9cutable. Cliquez \u2018G\u00e9n\u00e9rer\u2019 et v\u00e9rifiez. Exemple : (age > 120) signale les \u00e2ges impossibles."
  ),
  s4_c       = list(en = "C \u2013 Save the Check", de = "C \u2013 Pr\u00fcfung speichern", fr = "C \u2013 Enregistrer"),
  s4_c_hint  = list(
    en = "Why: Name, severity, and description let you and your team understand each check later. The timestamp ensures traceability.",
    de = "Warum: Name, Schweregrad und Beschreibung erm\u00f6glichen sp\u00e4teres Verst\u00e4ndnis. Der Zeitstempel gew\u00e4hrleistet R\u00fcckverfolgbarkeit.",
    fr = "Pourquoi : Nom, s\u00e9v\u00e9rit\u00e9 et description permettent la compr\u00e9hension ult\u00e9rieure. L\u2019horodatage assure la tra\u00e7abilit\u00e9."
  ),
  
  # ── Step 5: Results ────────────────────────────────────────────────────────
  s5_title    = list(en = "Step 5 \u2013 Results & Data Fitness", de = "Schritt 5 \u2013 Ergebnisse & Datenqualit\u00e4t", fr = "\u00c9tape 5 \u2013 R\u00e9sultats"),
  s5_checks   = list(en = "Checks Run", de = "Pr\u00fcfungen", fr = "V\u00e9rifications"),
  s5_issues   = list(en = "Issues Found", de = "Probleme", fr = "Probl\u00e8mes"),
  s5_affected = list(en = "Records Affected", de = "Betroffen", fr = "Affect\u00e9s"),
  s5_score_info = list(
    en = "Quality Score = 100% \u00d7 (1 \u2013 affected_records / total_records). 100% = no issues. Below 80% = significant problems.",
    de = "Quality Score = 100% \u00d7 (1 \u2013 betroffene / Gesamt). 100% = keine Probleme. Unter 80% = erhebliche Probleme.",
    fr = "Score = 100% \u00d7 (1 \u2013 affect\u00e9s / total). 100% = aucun probl\u00e8me. Sous 80% = probl\u00e8mes significatifs."
  ),
  s5_sev      = list(en = "Severity Distribution", de = "Schweregrad-Verteilung", fr = "Distribution de s\u00e9v\u00e9rit\u00e9"),
  s5_cat      = list(en = "Category Breakdown", de = "Kategorie-Verteilung", fr = "R\u00e9partition par cat\u00e9gorie"),
  s5_cat      = list(en = "Category Breakdown", de = "Kategorie-Verteilung", fr = "R\u00e9partition par cat\u00e9gorie"),
  s5_score_band_info = list(en = "Green 100-80 | Yellow 79-60 | Orange 59-40 | Red <40", de = "Gr\u00fcn 100-80 | Gelb 79-60 | Orange 59-40 | Rot <40", fr = "Vert 100-80 | Jaune 79-60 | Orange 59-40 | Rouge <40"),
  s5_detail   = list(en = "Detailed Issues", de = "Detaillierte Probleme", fr = "D\u00e9tails"),
  s5_detail   = list(en = "Detailed Issues", de = "Detaillierte Probleme", fr = "D\u00e9tails"),
  
  # ── Step 6: Cleansing ──────────────────────────────────────────────────────
  s6_title    = list(en = "Step 6 \u2013 Data Cleansing & Documentation", de = "Schritt 6 \u2013 Datenbereinigung & Dokumentation", fr = "\u00c9tape 6 \u2013 Nettoyage & Documentation"),
  s6_guide    = list(en = "Issue-Guided Cleansing", de = "Problemgef\u00fchrte Bereinigung", fr = "Nettoyage guid\u00e9"),
  s6_guide_hint = list(
    en = "Select an issue \u2192 navigate patient by patient \u2192 decide: keep, modify, or remove. Every action is logged.",
    de = "Problem w\u00e4hlen \u2192 Patient f\u00fcr Patient durchgehen \u2192 entscheiden: behalten, \u00e4ndern oder entfernen. Jede Aktion wird protokolliert.",
    fr = "S\u00e9lectionnez un probl\u00e8me \u2192 naviguez patient par patient \u2192 d\u00e9cidez : garder, modifier ou supprimer. Chaque action est journalis\u00e9e."
  ),
  s6_bulk     = list(en = "Bulk Operations", de = "Massenoperationen", fr = "Op\u00e9rations en masse"),
  s6_manual   = list(en = "Manual Cell Editing", de = "Manuelle Zellbearbeitung", fr = "\u00c9dition manuelle"),
  s6_log      = list(en = "Audit Trail & Change Log", de = "\u00c4nderungsprotokoll", fr = "Piste d\u2019audit"),
  s6_compare  = list(en = "Original vs. Cleaned", de = "Original vs. Bereinigt", fr = "Original vs. Nettoy\u00e9"),
  s6_rename   = list(en = "Rename Column", de = "Spalte umbenennen", fr = "Renommer"),
  s6_datefix  = list(en = "Fix Date Format", de = "Datumsformat korrigieren", fr = "Corriger les dates"),
  
  # ── Interpretation ─────────────────────────────────────────────────────────
  interp_ok = list(en = "Excellent \u2013 all checks passed. Data is ready for analysis.", de = "Exzellent \u2013 alle Pr\u00fcfungen bestanden. Daten sind analysebereit.", fr = "Excellent \u2013 toutes les v\u00e9rifications r\u00e9ussies."),
  interp_lo = list(en = "Minor issues detected. Mostly informational \u2013 unlikely to significantly affect results.", de = "Geringf\u00fcgige Probleme. Kaum Einfluss auf Ergebnisse.", fr = "Probl\u00e8mes mineurs. Peu d\u2019impact significatif."),
  interp_md = list(en = "Moderate issues. May introduce bias. Targeted cleansing recommended.", de = "Mittlere Probleme. K\u00f6nnten Verzerrungen verursachen. Gezielte Bereinigung empfohlen.", fr = "Probl\u00e8mes mod\u00e9r\u00e9s. Nettoyage cibl\u00e9 recommand\u00e9."),
  interp_hi = list(en = "Significant problems. Cleansing strongly recommended before analysis.", de = "Erhebliche Probleme. Bereinigung vor Analyse dringend empfohlen.", fr = "Probl\u00e8mes significatifs. Nettoyage fortement recommand\u00e9."),
  interp_cr = list(en = "Critical \u2013 do NOT use data without resolving these first.", de = "Kritisch \u2013 Daten NICHT ohne Behebung verwenden.", fr = "Critique \u2013 N\u2019utilisez PAS les donn\u00e9es sans r\u00e9solution."),
  
  # ── Finish page ────────────────────────────────────────────────────────────
  finish_title = list(en = "Thank You for Using Open DQA", de = "Vielen Dank f\u00fcr die Nutzung von Open DQA", fr = "Merci d\u2019avoir utilis\u00e9 Open DQA"),
  finish_recap = list(en = "Summary of Your Analysis", de = "Zusammenfassung Ihrer Analyse", fr = "R\u00e9sum\u00e9 de votre analyse"),
  finish_feedback = list(
    en = "We value your feedback! Please contact the development team:",
    de = "Wir freuen uns \u00fcber Ihr Feedback! Kontaktieren Sie das Entwicklerteam:",
    fr = "Vos retours sont pr\u00e9cieux ! Contactez l\u2019\u00e9quipe de d\u00e9veloppement :"
  ),
  finish_new = list(en = "Start New Analysis", de = "Neue Analyse starten", fr = "Nouvelle analyse"),
  
  # ── Tutorial ───────────────────────────────────────────────────────────────
  tut_title = list(en = "Interactive Tutorial", de = "Interaktives Tutorial", fr = "Tutoriel interactif"),
  tut_sub   = list(
    en = "Click each step to expand. After reading all steps, you will be fully prepared.",
    de = "Klicken Sie auf jeden Schritt. Danach sind Sie vorbereitet.",
    fr = "Cliquez sur chaque \u00e9tape. Apr\u00e8s lecture, vous serez pr\u00eat."
  ),
  tut_back  = list(en = "Back to Welcome", de = "Zur\u00fcck", fr = "Retour"),
  
  # ── New: Comparison type (Step 4) ──────────────────────────────────────────
  s4_comp_type = list(en = "Comparison Type", de = "Vergleichstyp", fr = "Type de comparaison"),
  s4_comp_val  = list(en = "Column vs. Value", de = "Spalte vs. Wert", fr = "Colonne vs. Valeur"),
  s4_comp_col  = list(en = "Column vs. Column", de = "Spalte vs. Spalte", fr = "Colonne vs. Colonne"),
  s4_comp_col2 = list(en = "Compare Column", de = "Vergleichsspalte", fr = "Colonne de comparaison"),
  
  # ── New: Cleansing actions (Step 6) ────────────────────────────────────────
  s6_keep       = list(en = "Keep As Is", de = "Beibehalten", fr = "Garder tel quel"),
  s6_edit_val   = list(en = "Edit Value", de = "Wert bearbeiten", fr = "\u00c9diter la valeur"),
  s6_save_edit  = list(en = "Save Edit", de = "Bearbeitung speichern", fr = "Enregistrer"),
  s6_fr_regex   = list(en = "Use Regex", de = "Regex verwenden", fr = "Utiliser Regex"),
  s6_fr_case    = list(en = "Case Sensitive", de = "Gro\u00df-/Kleinschreibung", fr = "Sensible \u00e0 la casse"),
  s6_fr_preview = list(en = "Preview Matches", de = "Treffer anzeigen", fr = "Aper\u00e7u des correspondances"),
  s6_fr_count   = list(en = "matches found", de = "Treffer gefunden", fr = "correspondances trouv\u00e9es"),
  
  # ── Landing page ───────────────────────────────────────────────────────────
  landing_title = list(en = "Tell us about yourself (optional)", de = "Erz\u00e4hlen Sie uns von sich (optional)", fr = "Parlez-nous de vous (optionnel)"),
  landing_sub = list(en = "This information will be included in generated reports. You can skip.", de = "Diese Informationen erscheinen in Berichten. Sie k\u00f6nnen \u00fcberspringen.", fr = "Ces informations figureront dans les rapports. Vous pouvez passer."),
  landing_name = list(en = "Your Name", de = "Ihr Name", fr = "Votre nom"),
  landing_function = list(en = "Your Role / Function", de = "Ihre Rolle / Funktion", fr = "Votre r\u00f4le / fonction"),
  landing_email = list(en = "Email (for report delivery)", de = "E-Mail (f\u00fcr Berichtsversand)", fr = "E-mail (pour envoi de rapports)"),
  landing_skip = list(en = "Skip & Continue", de = "\u00dcberspringen", fr = "Passer"),
  landing_save = list(en = "Save & Continue", de = "Speichern & Weiter", fr = "Enregistrer & Continuer"),
  
  # ──  Assistant ─────────────────────────────────────────────────────
  ai_assist_title = list(en = "\U0001F916  Assistant", de = "\U0001F916 ML-basierter Assistent", fr = "\U0001F916 Assistant ML"),
  ai_checks_hint = list(en = " analysis of your data to suggest custom checks.", de = "ML-basierte Analyse Ihrer Daten f\u00fcr Pr\u00fcfungsvorschl\u00e4ge.", fr = "Analyse ML de vos donn\u00e9es pour sugg\u00e9rer des v\u00e9rifications."),
  ai_cleanse_title = list(en = "\U0001F916  Cleansing Assistant", de = "\U0001F916 ML-basierter Bereinigungsassistent", fr = "\U0001F916 Assistant de nettoyage ML"),
  ai_cleanse_hint = list(en = "Cluster-based anomaly detection identifies problems and proposes corrections. You decide.", de = "Clusterbasierte Anomalieerkennung. Sie entscheiden.", fr = "D\u00e9tection d'anomalies par clustering. Vous d\u00e9cidez."),
  
  # ── Performance ────────────────────────────────────────────────────────────
  perf_title = list(en = "Performance Metrics", de = "Leistungsmetriken", fr = "M\u00e9triques de performance"),
  
  # ── Email on Finish ────────────────────────────────────────────────────────
  finish_email_sent = list(en = "\u2709 Reports sent to your email.", de = "\u2709 Berichte an E-Mail gesendet.", fr = "\u2709 Rapports envoy\u00e9s par e-mail."),
  finish_email_skip = list(en = "No email provided \u2013 reports available for download only.", de = "Keine E-Mail \u2013 nur Download.", fr = "Pas d'e-mail \u2013 t\u00e9l\u00e9chargement uniquement.")
)

# Convenience i18n accessor
i18n <- function(k, l = "en") {
  e <- I18N[[k]]
  if (is.null(e)) return(k)
  v <- e[[l]]
  if (is.null(v)) v <- e[["en"]]
  if (is.null(v)) return(k)
  v
}

# ── Section 3: Data Readers ──────────────────────────────────────────────────
# All readers return a standard data.frame. They handle edge cases gracefully.

as_rectangular <- function(x) {
  if (is.data.frame(x)) return(as.data.frame(x))
  if (is.null(x)) return(data.frame())
  for (k in c("data","results","items","records","entry","hits","rows"))
    if (is.list(x) && !is.null(x[[k]])) return(as_rectangular(x[[k]]))
  if (is.list(x)) {
    try({
      lst <- lapply(x, function(e) as.data.frame(jsonlite::flatten(e), stringsAsFactors = FALSE))
      return(as.data.frame(data.table::rbindlist(lst, fill = TRUE)))
    }, silent = TRUE)
  }
  as.data.frame(x, stringsAsFactors = FALSE)
}

read_json_tabular <- function(path) {
  df <- tryCatch({
    obj <- jsonlite::fromJSON(path, flatten = TRUE)
    as_rectangular(obj)
  }, error = function(e) NULL)
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) {
    con <- file(path, open = "r"); on.exit(close(con))
    df <- tryCatch(jsonlite::stream_in(con, flatten = TRUE, verbose = FALSE), error = function(e) NULL)
  }
  if (is.null(df) || !is.data.frame(df) || nrow(df) == 0) {
    lines <- readLines(path, warn = FALSE)
    recs <- lapply(lines[nzchar(lines)], function(z) tryCatch(jsonlite::fromJSON(z, flatten = TRUE), error = function(e) NULL))
    recs <- recs[!vapply(recs, is.null, logical(1))]
    if (length(recs))
      df <- as.data.frame(data.table::rbindlist(
        lapply(recs, function(e) as.data.frame(jsonlite::flatten(e), stringsAsFactors = FALSE)),
        fill = TRUE))
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
  fc  <- function(c) if (is.null(c) || !length(c)) NA_character_ else as.character(c[[1]]$code %||% NA)
  pdf <- if (length(pts)) data.frame(
    patient_id = vapply(pts, function(p) as.character(p$id %||% NA), character(1)),
    gender     = vapply(pts, function(p) as.character(p$gender %||% NA), character(1)),
    birth_date = vapply(pts, function(p) as.character(p$birthDate %||% NA), character(1)),
    stringsAsFactors = FALSE
  ) else data.frame(patient_id = character(), gender = character(), birth_date = character())
  edf <- if (length(enc)) data.frame(
    patient_id     = vapply(enc, function(e) gri(e$subject$reference %||% NA), character(1)),
    admission_date = vapply(enc, function(e) as.character(e$period$start %||% NA), character(1)),
    discharge_date = vapply(enc, function(e) as.character(e$period$end %||% NA), character(1)),
    stringsAsFactors = FALSE
  ) else data.frame(patient_id = character(), admission_date = character(), discharge_date = character())
  cdf <- if (length(cnd)) data.frame(
    patient_id = vapply(cnd, function(cn) gri(cn$subject$reference %||% NA), character(1)),
    icd = vapply(cnd, function(cn) fc((cn$code$coding %||% list())[1]), character(1)),
    stringsAsFactors = FALSE
  ) else data.frame(patient_id = character(), icd = character())
  prf <- if (length(prc)) data.frame(
    patient_id = vapply(prc, function(pr) gri(pr$subject$reference %||% NA), character(1)),
    ops = vapply(prc, function(pr) fc((pr$code$coding %||% list())[1]), character(1)),
    stringsAsFactors = FALSE
  ) else data.frame(patient_id = character(), ops = character())
  if (nrow(cdf)) cdf <- cdf |> group_by(patient_id) |> summarise(icd = paste(unique(na.omit(icd)), collapse = "; "), .groups = "drop")
  if (nrow(prf)) prf <- prf |> group_by(patient_id) |> summarise(ops = paste(unique(na.omit(ops)), collapse = "; "), .groups = "drop")
  out <- if (nrow(edf)) {
    edf |> left_join(pdf, by = "patient_id") |> left_join(cdf, by = "patient_id") |> left_join(prf, by = "patient_id")
  } else {
    full_join(pdf, cdf, by = "patient_id") |> full_join(prf, by = "patient_id") |>
      mutate(admission_date = NA_character_, discharge_date = NA_character_)
  }
  for (dc in c("birth_date", "admission_date", "discharge_date"))
    if (dc %in% names(out)) out[[dc]] <- suppressWarnings(as.Date(out[[dc]]))
  out
}

# ── SQL / DB helpers (robust connections, no new dependencies) ────────────────

odqa_trim <- function(x) {
  if (is.null(x)) return("")
  trimws(as.character(x))
}
odqa_int <- function(x) suppressWarnings(as.integer(x))

odqa_disconnect_safe <- function(con) {
  if (is.null(con)) return(invisible(FALSE))
  tryCatch({
    # dbIsValid exists when DBI is available; guard with tryCatch anyway
    if (inherits(con, "DBIConnection") && DBI::dbIsValid(con)) DBI::dbDisconnect(con)
  }, error = function(e) NULL)
  invisible(TRUE)
}

odqa_pick_mssql_driver <- function() {
  if (!exists("sql_ms", inherits = TRUE) || !isTRUE(sql_ms)) return(NULL)
  
  drv_tbl <- tryCatch(odbc::odbcListDrivers(), error = function(e) NULL)
  if (is.null(drv_tbl) || nrow(drv_tbl) == 0) return(NULL)
  
  # ODBC driver list column names vary by OS
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

odqa_db_connect <- function(db_type, host, port, dbname, user, password,
                            connect_timeout = 10L, retries = 1L, retry_wait_sec = 0.5) {
  db_type <- odqa_trim(db_type)
  if (!nzchar(db_type)) db_type <- "PostgreSQL"
  
  host   <- odqa_trim(host)
  dbname <- odqa_trim(dbname)
  user   <- odqa_trim(user)
  port_i <- odqa_int(port)
  if (is.null(password)) password <- ""
  
  if (!nzchar(host))   stop("Host is empty.")
  if (!nzchar(dbname)) stop("Database is empty.")
  if (!nzchar(user))   stop("User is empty.")
  if (is.na(port_i) || port_i < 1L) stop("Port must be a positive integer.")
  
  last_err <- NULL
  
  for (attempt in 0:retries) {
    con <- NULL
    
    ok <- tryCatch({
      if (identical(db_type, "PostgreSQL")) {
        if (!exists("sql_pg", inherits = TRUE) || !isTRUE(sql_pg)) {
          stop("PostgreSQL support requires packages DBI + RPostgres (not available in this runtime).")
        }
        
        con <- DBI::dbConnect(
          RPostgres::Postgres(),
          host = host,
          port = port_i,
          dbname = dbname,
          user = user,
          password = password,
          sslmode = getOption("odqa.pg.sslmode", "prefer"),
          connect_timeout = as.integer(getOption("odqa.pg.connect_timeout", connect_timeout)),
          application_name = "OpenDQA"
        )
        
      } else if (identical(db_type, "Microsoft SQL")) {
        if (!exists("sql_ms", inherits = TRUE) || !isTRUE(sql_ms)) {
          stop("Microsoft SQL support requires packages DBI + odbc (not available in this runtime).")
        }
        
        drv <- getOption("odqa.mssql.driver", odqa_pick_mssql_driver())
        if (is.null(drv) || !nzchar(drv)) {
          stop("No SQL Server ODBC driver found. Install Microsoft ODBC Driver 18/17 for SQL Server or configure an ODBC DSN.")
        }
        
        args <- list(
          odbc::odbc(),
          Driver   = drv,
          Server   = paste0(host, ",", port_i),
          Database = dbname,
          UID      = user,
          PWD      = password,
          Timeout  = as.integer(getOption("odqa.mssql.connect_timeout", connect_timeout))
        )
        
        # Driver 18 defaults to Encrypt=yes and can fail without a trusted certificate.
        # This keeps it working out-of-the-box; override via options if needed.
        if (grepl("ODBC Driver 18", drv, ignore.case = TRUE)) {
          args$Encrypt <- getOption("odqa.mssql.encrypt", "yes")
          args$TrustServerCertificate <- getOption("odqa.mssql.trust_server_cert", "yes")
        }
        
        con <- do.call(DBI::dbConnect, args)
        
      } else {
        stop("Unsupported database type: ", db_type)
      }
      
      TRUE
    }, error = function(e) {
      last_err <<- e
      odqa_disconnect_safe(con)
      con <<- NULL
      FALSE
    })
    
    if (isTRUE(ok) && !is.null(con)) return(con)
    if (attempt < retries) Sys.sleep(retry_wait_sec)
  }
  
  stop(last_err$message)
}

odqa_db_query <- function(con, query) {
  if (is.null(con)) stop("No database connection.")
  query <- as.character(query)
  if (!nzchar(trimws(query))) stop("SQL query is empty.")
  
  res <- DBI::dbSendQuery(con, query)
  on.exit(try(DBI::dbClearResult(res), silent = TRUE), add = TRUE)
  
  out <- DBI::dbFetch(res)
  as.data.frame(out)
}

# Drop-in replacement used by the app
read_sql_query <- function(host, port, dbname, user, password, query, db_type = "PostgreSQL") {
  con <- odqa_db_connect(
    db_type = db_type,
    host = host, port = port, dbname = dbname,
    user = user, password = password
  )
  on.exit(odqa_disconnect_safe(con), add = TRUE)
  
  odqa_db_query(con, query)
}


read_file <- function(type, csv_f = NULL, csv_h = TRUE, csv_s = ",",
                      xls_f = NULL, xls_sh = 1, json_f = NULL, fhir_f = NULL) {
  o <- NULL
  if (type == "CSV/TXT" && !is.null(csv_f))
    o <- tryCatch(as.data.frame(data.table::fread(csv_f$datapath, header = csv_h, sep = csv_s, data.table = FALSE)), error = function(e) NULL)
  else if (type == "Excel" && !is.null(xls_f))
    o <- tryCatch(as.data.frame(readxl::read_excel(xls_f$datapath, sheet = xls_sh)), error = function(e) NULL)
  else if (type == "JSON" && !is.null(json_f))
    o <- tryCatch(read_json_tabular(json_f$datapath), error = function(e) NULL)
  else if (type == "FHIR Bundle" && !is.null(fhir_f))
    o <- tryCatch(read_fhir_tabular(fhir_f$datapath), error = function(e) NULL)
  o
}

# ── Section 4: ICD-10 & OPS Validators ───────────────────────────────────────
# These work with ICD-10-GM but also catch common issues in any ICD-10 variant.

.icd_re    <- function() stringr::regex("^[A-Z][0-9]{2}(\\.[0-9A-Z]{1,4})?$", ignore_case = TRUE)
icd_valid  <- function(x) stringr::str_detect(x, .icd_re())
icd_norm   <- function(x) { y <- gsub("\\s+", "", x); y <- toupper(y); chartr("OI", "01", y) }
icd_unspec <- function(x) { u <- icd_norm(x); str_detect(u, "(^R99$)|(^Z00(\\.|$))|(\\.(9|90|99|9[A-Z0-9]{1,3})$)") }
.ops_re    <- function() stringr::regex("^[1-9]-[0-9]{2,3}(\\.[0-9A-Z]{1,3}){0,2}$", ignore_case = TRUE)
ops_valid  <- function(x) stringr::str_detect(x, .ops_re())
ndash      <- function(s) gsub("[\u2010\u2011\u2012\u2013\u2014\u2212]", "-", s)
ops_norm   <- function(x) {
  y <- ndash(x); y <- gsub("\\s+", "", y); y <- toupper(y); y <- chartr("OI", "01", y)
  ifelse(!grepl("^[0-9]-", y) & grepl("^[0-9]", y), paste0(substr(y, 1, 1), "-", substr(y, 2, nchar(y))), y)
}

# ── Section 5: Utilities ─────────────────────────────────────────────────────

`%null%` <- function(x, y) if (is.null(x)) y else x
with_waiter <- function(expr, label = "Working\u2026") {
  w <- waiter::Waiter$new(html = tagList(waiter::spin_fading_circles(), h4(label)))
  w$show(); on.exit(w$hide(), add = TRUE); force(expr)
}
safe_notify <- function(msg, type = c("message", "warning", "error")) {
  type <- match.arg(type)
  try(showNotification(msg, type = type, duration = 4), silent = TRUE)
}
pcv <- function(s) {
  if (is.null(s) || length(s) == 0) return(character(0))
  vals <- unlist(strsplit(s, ",", fixed = TRUE))
  unique(tolower(trimws(as.character(vals)))[nzchar(trimws(as.character(vals)))])
}
std_gender <- function(x, gmap) {
  sx <- tolower(trimws(as.character(x)))
  ms <- pcv(gmap$male %||% ""); fs <- pcv(gmap$female %||% "")
  o <- sx
  if (length(ms)) o[sx %in% ms] <- "male"
  if (length(fs)) o[sx %in% fs] <- "female"
  o
}
# ── PATCH v2.2: Stability + AI + Reporting Helpers (no new deps) ─────────────

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
  # robust-ish numeric conversion for mixed locale input
  y <- suppressWarnings(as.character(x))
  y <- gsub("[[:space:]]", "", y)
  # keep digits, sign, dot, comma
  y <- gsub("[^0-9\\-\\+\\,\\.]", "", y)
  # if comma is decimal (e.g., 12,3) and dot used as thousands (1.234,5)
  # heuristic: if both present, remove dots then comma->dot
  both <- grepl("\\.", y) & grepl(",", y)
  y[both] <- gsub("\\.", "", y[both])
  y <- gsub(",", ".", y, fixed = TRUE)
  suppressWarnings(as.numeric(y))
}

sample_idx <- function(n, sample_n = 50000, seed = 1) {
  n <- as.integer(n); sample_n <- as.integer(sample_n)
  if (is.na(n) || n <= 0) return(integer(0))
  if (n <= sample_n) return(seq_len(n))
  set.seed(seed)
  sort(sample.int(n, sample_n, replace = FALSE))
}

ai_entropy <- function(tab) {
  p <- tab / max(sum(tab), 1)
  p <- p[p > 0]
  -sum(p * log(p))
}

ai_typos_hint <- function(vals, max_levels = 200) {
  # detect near-duplicates among categorical levels (base R only)
  v <- unique(trimws(tolower(as.character(vals))))
  v <- v[nzchar(v)]
  if (length(v) < 10) return("")
  if (length(v) > max_levels) v <- sample(v, max_levels)
  # compute distances for a small sample
  d <- utils::adist(v)
  diag(d) <- 999
  pairs <- which(d > 0 & d <= 1, arr.ind = TRUE)
  if (nrow(pairs) == 0) return("")
  # show a few examples
  ex <- apply(pairs[seq_len(min(4, nrow(pairs))), , drop = FALSE], 1, function(ix) {
    paste0("'", v[ix[1]], "' ~ '", v[ix[2]], "'")
  })
  paste0("Possible typos / near-duplicates: ", paste(unique(ex), collapse = ", "), ".")
}

score_band <- function(score) {
  s <- as.numeric(score)
  if (is.na(s)) return("red")
  if (s >= 80) return("green")
  if (s >= 60) return("yellow")
  if (s >= 40) return("orange")
  "red"
}

score_hex <- function(score) {
  # readable defaults (no theme dependency)
  b <- score_band(score)
  switch(b,
         green  = "#16a34a",
         yellow = "#ca8a04",
         orange = "#ea580c",
         red    = "#dc2626")
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

issues_by_check <- function(issues_df, checks_df, n_total) {
  if (is.null(issues_df) || nrow(issues_df) == 0) {
    return(data.frame(check_id = character(), check_name = character(), severity = character(),
                      affected_n = integer(), affected_pct = numeric(),
                      required = character(), stringsAsFactors = FALSE))
  }
  n_total <- max(as.integer(n_total), 1L)
  # unique rows per check
  agg <- aggregate(issues_df$row, by = list(check_id = issues_df$check_id), function(x) length(unique(x)))
  names(agg)[2] <- "affected_n"
  agg$affected_pct <- round(100 * agg$affected_n / n_total, 2)
  
  # severity per check: take the worst observed
  sev_rank <- c(Low = 1, Medium = 2, High = 3, Critical = 4)
  sev_agg <- aggregate(issues_df$severity, by = list(check_id = issues_df$check_id), function(x) {
    x <- as.character(x)
    x[is.na(x) | !nzchar(x)] <- "Low"
    x <- intersect(x, names(sev_rank))
    if (!length(x)) return("Low")
    x[which.max(sev_rank[x])]
  })
  names(sev_agg)[2] <- "severity"
  
  out <- merge(agg, sev_agg, by = "check_id", all.x = TRUE)
  
  meta <- checks_df[, intersect(names(checks_df), c("check_id", "check_name", "description", "required", "severity"))]
  if (!"check_name" %in% names(meta)) meta$check_name <- meta$description
  out <- merge(out, meta, by = "check_id", all.x = TRUE)
  
  # prefer observed severity
  out$severity <- out$severity.x %||% out$severity.y
  out$severity.x <- NULL; out$severity.y <- NULL
  
  out <- out[order(-out$affected_pct, -out$affected_n), ]
  rownames(out) <- NULL
  out
}

plot_check_impact <- function(affected_n, total_n, main, subtitle = NULL) {
  total_n  <- max(as.integer(total_n), 1L)
  affected_n <- max(as.integer(affected_n), 0L)
  ok_n     <- max(total_n - affected_n, 0L)
  pct_aff  <- round(100 * affected_n / total_n, 2)
  pct_ok   <- round(100 - pct_aff, 2)
  
  oldpar <- par(no.readonly = TRUE)
  on.exit(par(oldpar), add = TRUE)
  
  # ── Dual-panel layout: stacked bar (left) + donut (right) ──
  layout(matrix(c(1, 2), nrow = 1), widths = c(2.2, 1))
  
  # ── Panel 1: Horizontal stacked bar with percentage labels ──
  par(mar = c(4, 1, 4, 1))
  vals <- c(ok_n, affected_n)
  cols <- c("#10B981", "#EF4444")
  
  bp <- barplot(rev(vals), horiz = TRUE, col = rev(cols), border = NA,
                axes = FALSE, xlim = c(0, total_n), names.arg = "")
  
  # Axis with formatted numbers
  axis(1, las = 1, col = "#CED0D4", col.axis = "#606770", cex.axis = 0.8)
  title(main = main, cex.main = 0.95, font.main = 2, col.main = "#1C1E21")
  if (!is.null(subtitle)) {
    title(sub = subtitle, cex.sub = 0.8, col.sub = "#606770", line = 2.5)
  }
  
  # Labels inside the bars
  mid_ok  <- ok_n / 2
  mid_aff <- ok_n + affected_n / 2
  
  if (pct_ok >= 8) {
    text(mid_ok, bp, labels = paste0("OK: ", format(ok_n, big.mark = ","),
                                     " (", pct_ok, "%)"), cex = 0.8, font = 2, col = "white")
  }
  if (pct_aff >= 8) {
    text(mid_aff, bp, labels = paste0("Affected: ", format(affected_n, big.mark = ","),
                                      " (", pct_aff, "%)"), cex = 0.8, font = 2, col = "white")
  }
  
  # Legend below bar
  legend("bottom", inset = c(0, -0.22), xpd = TRUE, horiz = TRUE,
         legend = c(paste0("OK (", pct_ok, "%)"), paste0("Affected (", pct_aff, "%)")),
         fill = cols, border = NA, cex = 0.75, bty = "n")
  
  # ── Panel 2: Donut chart for visual percentage ──
  par(mar = c(2, 0, 2, 2))
  
  # Draw pie with hole for donut effect
  if (affected_n == 0) {
    pie_vals <- 1
    pie_cols <- "#10B981"
    pie_labels <- "100%\nOK"
  } else if (ok_n == 0) {
    pie_vals <- 1
    pie_cols <- "#EF4444"
    pie_labels <- "100%\nAffected"
  } else {
    pie_vals <- c(ok_n, affected_n)
    pie_cols <- cols
    pie_labels <- c("", "")
  }
  
  pie(pie_vals, labels = pie_labels, col = pie_cols, border = "white",
      radius = 0.9, cex = 0.7, init.angle = 90)
  
  # White circle in center for donut effect + center label
  symbols(0, 0, circles = 0.45, add = TRUE, inches = FALSE,
          bg = "white", fg = "white")
  text(0, 0.05, labels = paste0(pct_aff, "%"), cex = 1.4, font = 2,
       col = "#EF4444")
  text(0, -0.15, labels = "affected", cex = 0.7, col = "#606770")
  
  # Reset layout
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

# ── Crash-proof UNDO for large data: stores snapshots on disk if needed ───────
cl_undo_push <- function(rv, data_obj, max_steps = 5, disk_threshold_mb = 50) {
  if (is.null(data_obj)) return(invisible(FALSE))
  sz_mb <- as.numeric(object.size(data_obj)) / 1024^2
  entry <- NULL
  
  # For large datasets: always save to disk with xz compression
  if (!is.na(sz_mb) && sz_mb >= disk_threshold_mb) {
    f <- tempfile("odqa_undo_", fileext = ".rds")
    ok <- tryCatch({
      saveRDS(data_obj, f, compress = "xz")
      TRUE
    }, error = function(e) FALSE)
    if (ok && file.exists(f)) {
      rv$cl_undo_files <- c(rv$cl_undo_files, f)
      entry <- list(type = "rds", path = f, size_mb = round(sz_mb, 1))
    }
  }
  
  # For smaller datasets: keep in memory
  if (is.null(entry)) {
    entry <- list(type = "obj", obj = data_obj, size_mb = round(sz_mb, 1))
  }
  
  rv$cl_undo_stack <- c(rv$cl_undo_stack, list(entry))
  
  # Adaptive max_steps: fewer undo steps for very large datasets
  effective_max <- if (sz_mb > 500) 2L else if (sz_mb > 100) 3L else max_steps
  
  while (length(rv$cl_undo_stack) > effective_max) {
    drop <- rv$cl_undo_stack[[1]]
    rv$cl_undo_stack <- rv$cl_undo_stack[-1]
    if (!is.null(drop$type) && drop$type == "rds" &&
        !is.null(drop$path) && file.exists(drop$path)) {
      try(unlink(drop$path), silent = TRUE)
    }
  }
  invisible(TRUE)
}

cl_undo_pop <- function(rv) {
  if (length(rv$cl_undo_stack) == 0) return(NULL)
  entry <- rv$cl_undo_stack[[length(rv$cl_undo_stack)]]
  rv$cl_undo_stack <- rv$cl_undo_stack[-length(rv$cl_undo_stack)]
  if (is.null(entry$type)) return(NULL)
  if (entry$type == "obj") return(entry$obj)
  if (entry$type == "rds" && !is.null(entry$path) && file.exists(entry$path)) {
    out <- tryCatch(readRDS(entry$path), error = function(e) NULL)
    try(unlink(entry$path), silent = TRUE)
    return(out)
  }
  NULL
}

# ── End PATCH v2.2 ───────────────────────────────────────────────────────────

auto_map <- function(cn) {
  lc <- tolower(cn)
  g <- function(pat) { h <- grepl(pat, lc); if (any(h)) cn[h][1] else NULL }
  list(
    patient_id     = g("patientid|pat_id|patient_id|pat_nr|fallnr"),
    icd            = g("^icd$|icd_code|icd10|diagnosis|diagnose"),
    ops            = g("^ops$|ops_code|procedure|prozedur"),
    gender         = g("gender|sex|geschlecht"),
    admission_date = g("admission|aufnahme"),
    discharge_date = g("discharge|entlassung"),
    age            = g("^age$|^alter$"),
    birth_date     = g("birth|geburt"),
    anamnese       = g("anamnese|text|befund|notes|comment")
  )
}

# ── Patient ID redaction for email reports ───────────────────────────────────
redact_patient_ids <- function(df) {
  if (is.null(df) || nrow(df) == 0) return(df)
  pid_cols <- grep("patient.?id|pat.?id|pat.?nr|fallnr|case.?id|subject.?id", tolower(names(df)), value = TRUE)
  for (col in pid_cols) if (col %in% names(df)) df[[col]] <- paste0("REDACTED_", seq_len(nrow(df)))
  df
}

# ── ML: Column Type Classifier ───────────────────────────────────────────────
# Determines the semantic type of a column with high accuracy by analyzing
# actual values, not just R class. Returns one of:
#   "numeric", "integer", "date", "datetime", "categorical",
#   "binary", "id", "code_icd", "code_ops", "freetext", "mixed"

ai_type_classifier <- function(vals, max_sample = 5000L) {
  if (is.null(vals) || length(vals) == 0) return("empty")
  
  n <- length(vals)
  
  # Fast sampling (avoid scanning full column)
  if (n > max_sample) {
    idx <- sample.int(n, min(n, max_sample * 2L))
    vals_s <- vals[idx]
  } else {
    vals_s <- vals
  }
  
  if (is.factor(vals_s)) vals_s <- as.character(vals_s)
  
  # remove empties in sample only
  if (is.character(vals_s)) {
    non_na <- vals_s[!is.na(vals_s) & nzchar(trimws(vals_s))]
  } else {
    non_na <- vals_s[!is.na(vals_s)]
  }
  if (length(non_na) == 0) return("empty")
  
  # numeric detection
  if (is.numeric(non_na) || is.integer(non_na)) {
    if (is.integer(non_na)) return("integer")
    return("numeric")
  }
  
  suppressWarnings(num_try <- as.numeric(non_na))
  num_ratio <- mean(!is.na(num_try))
  if (num_ratio > 0.9) {
    if (mean(abs(num_try[!is.na(num_try)] - round(num_try[!is.na(num_try)])) < 1e-9) > 0.9)
      return("integer")
    return("numeric")
  }
  
  # date/datetime
  if (inherits(non_na, "Date") || inherits(non_na, "POSIXt")) {
    if (inherits(non_na, "POSIXt")) return("datetime")
    return("date")
  }
  
  xchr <- as.character(non_na)
  xchr <- xchr[nzchar(trimws(xchr))]
  if (length(xchr) == 0) return("empty")
  
  dt_try <- suppressWarnings(as.Date(xchr))
  if (mean(!is.na(dt_try)) > 0.8) return("date")
  
  # Code patterns
  if (mean(grepl("^[A-Za-z][0-9]{2}(\\.[0-9A-Za-z]{1,4})?$", xchr)) > 0.6) return("code_icd")
  if (mean(grepl("^[0-9]-[0-9]{2,3}(\\.[0-9A-Za-z]{1,3})?$", xchr)) > 0.6) return("code_ops")
  
  ux <- unique(xchr)
  if (length(ux) <= 2) return("binary")
  if (length(ux) <= 30) return("categorical")
  
  # ID heuristic: high uniqueness, typically short/medium length
  if (length(ux) / length(xchr) > 0.9 && median(nchar(xchr), na.rm = TRUE) <= 40) return("id")
  
  if (median(nchar(xchr), na.rm = TRUE) > 50) return("freetext")
  "categorical"
}


# ── ML: Numeric Anomaly Detection ────────────────────────────────────────────
# Uses adaptive methods: IQR, Z-score, Grubbs-like test, distribution analysis,
# impossible-value detection, and digit-preference analysis.

ai_numeric_anomalies <- function(vals, col_name, lang = "en") {
  results <- list()
  num_vals <- suppressWarnings(as.numeric(as.character(vals)))
  valid    <- num_vals[!is.na(num_vals)]
  n_valid  <- length(valid)
  if (n_valid < 5) return(results)
  
  mn  <- min(valid);  mx  <- max(valid)
  med <- median(valid); mu <- mean(valid)
  sd_ <- sd(valid)
  q1  <- quantile(valid, 0.25); q3 <- quantile(valid, 0.75)
  iqr <- q3 - q1
  
  # ── 1. Adaptive IQR outliers (Tukey) ────────────────────────────────────
  if (iqr > 0) {
    lower_mild   <- q1 - 1.5 * iqr;  upper_mild   <- q3 + 1.5 * iqr
    lower_extreme <- q1 - 3.0 * iqr; upper_extreme <- q3 + 3.0 * iqr
    
    extreme_idx <- which(!is.na(num_vals) & (num_vals < lower_extreme | num_vals > upper_extreme))
    mild_idx    <- which(!is.na(num_vals) & (num_vals < lower_mild | num_vals > upper_mild))
    mild_only   <- setdiff(mild_idx, extreme_idx)
    
    if (length(extreme_idx) > 0) {
      results$extreme_outliers <- list(
        rows     = extreme_idx,
        values   = num_vals[extreme_idx],
        severity = "high",
        type     = "extreme_outlier",
        suggestion = switch(lang,
                            de = paste0(length(extreme_idx), " extreme Ausreißer (>3×IQR): Werte außerhalb [",
                                        round(lower_extreme, 2), ", ", round(upper_extreme, 2), "]. Wahrscheinlich Datenfehler."),
                            fr = paste0(length(extreme_idx), " valeurs extrêmes (>3×IQR) hors [",
                                        round(lower_extreme, 2), ", ", round(upper_extreme, 2), "]. Probablement des erreurs."),
                            paste0(length(extreme_idx), " extreme outliers (>3×IQR) outside [",
                                   round(lower_extreme, 2), ", ", round(upper_extreme, 2), "]. Likely data errors.")),
        correction = paste0("Consider replacing with NA or median (", round(med, 2), ")")
      )
    }
    if (length(mild_only) > 0 && length(mild_only) <= n_valid * 0.1) {
      results$mild_outliers <- list(
        rows     = mild_only,
        values   = num_vals[mild_only],
        severity = "medium",
        type     = "mild_outlier",
        suggestion = switch(lang,
                            de = paste0(length(mild_only), " moderate Ausreißer (1.5-3×IQR). Prüfung empfohlen."),
                            fr = paste0(length(mild_only), " valeurs modérément aberrantes. Vérification recommandée."),
                            paste0(length(mild_only), " mild outliers (1.5-3×IQR). Review recommended.")),
        correction = "Review individually; may be valid extreme values"
      )
    }
  }
  
  # ── 2. Z-score outliers (for near-normal distributions) ─────────────────
  if (sd_ > 0 && n_valid > 30) {
    z_scores  <- abs((num_vals - mu) / sd_)
    z_extreme <- which(!is.na(z_scores) & z_scores > 4)
    # Only report if IQR method didn't already catch them
    z_new <- setdiff(z_extreme, c(results$extreme_outliers$rows, results$mild_outliers$rows))
    if (length(z_new) > 0 && length(z_new) <= 20) {
      results$zscore_outliers <- list(
        rows     = z_new,
        values   = num_vals[z_new],
        severity = "medium",
        type     = "zscore_outlier",
        suggestion = switch(lang,
                            de = paste0(length(z_new), " Werte mit |Z| > 4 (σ-basiert). Statistische Ausreißer."),
                            fr = paste0(length(z_new), " valeurs avec |Z| > 4. Aberrants statistiques."),
                            paste0(length(z_new), " values with |Z| > 4 (σ-based). Statistical outliers.")),
        correction = "Review context; may be recording errors"
      )
    }
  }
  
  # ── 3. Domain-specific impossible values ────────────────────────────────
  col_lower <- tolower(col_name)
  
  # Age checks
  if (grepl("age|alter|âge", col_lower)) {
    bad_age <- which(!is.na(num_vals) & (num_vals < 0 | num_vals > 130))
    if (length(bad_age) > 0) {
      results$impossible_age <- list(
        rows     = bad_age,
        values   = num_vals[bad_age],
        severity = "high",
        type     = "impossible_value",
        suggestion = switch(lang,
                            de = paste0(length(bad_age), " unmögliche Alterswerte (< 0 oder > 130)."),
                            fr = paste0(length(bad_age), " âges impossibles (< 0 ou > 130)."),
                            paste0(length(bad_age), " impossible age values (< 0 or > 130).")),
        correction = "Verify against source records"
      )
    }
    # Suspicious: negative or decimal ages
    suspect_age <- which(!is.na(num_vals) & (num_vals < 0 | (num_vals != floor(num_vals) & num_vals > 1)))
    suspect_age <- setdiff(suspect_age, bad_age)
    if (length(suspect_age) > 0) {
      results$suspect_age <- list(
        rows = suspect_age, values = num_vals[suspect_age],
        severity = "low", type = "suspect_value",
        suggestion = switch(lang,
                            de = paste0(length(suspect_age), " ungewöhnliche Alterswerte (negativ oder Dezimal)."),
                            fr = paste0(length(suspect_age), " âges inhabituels (négatifs ou décimaux)."),
                            paste0(length(suspect_age), " unusual age values (negative or decimal).")),
        correction = "Check if fractional ages are intended (e.g., neonates)"
      )
    }
  }
  
  # Weight checks (kg assumed)
  if (grepl("weight|gewicht|poids|kg|mass", col_lower)) {
    bad_w <- which(!is.na(num_vals) & (num_vals < 0.3 | num_vals > 400))
    if (length(bad_w) > 0) {
      results$impossible_weight <- list(
        rows = bad_w, values = num_vals[bad_w], severity = "high", type = "impossible_value",
        suggestion = paste0(length(bad_w), switch(lang,
                                                  de = " unmögliche Gewichtswerte (< 0.3 oder > 400 kg).",
                                                  fr = " valeurs de poids impossibles.",
                                                  " impossible weight values (< 0.3 or > 400 kg).")),
        correction = "Check unit consistency (kg vs lbs vs g)"
      )
    }
  }
  
  # Height checks (cm assumed)
  if (grepl("height|größe|groesse|taille|cm|length|länge", col_lower)) {
    bad_h <- which(!is.na(num_vals) & (num_vals < 20 | num_vals > 260))
    if (length(bad_h) > 0) {
      results$impossible_height <- list(
        rows = bad_h, values = num_vals[bad_h], severity = "high", type = "impossible_value",
        suggestion = paste0(length(bad_h), switch(lang,
                                                  de = " unmögliche Größenwerte.", fr = " tailles impossibles.",
                                                  " impossible height values.")),
        correction = "Check unit consistency (cm vs m vs inches)"
      )
    }
  }
  
  # ── 4. Distribution anomalies ───────────────────────────────────────────
  if (n_valid >= 30) {
    # Digit preference (heap at round numbers)
    last_digit <- valid %% 10
    digit_freq <- table(factor(last_digit, levels = 0:9))
    expected   <- n_valid / 10
    chi_stat   <- sum((digit_freq - expected)^2 / expected)
    # chi-sq with df=9, p<0.001 threshold ≈ 27.88
    if (chi_stat > 27.88) {
      top_digits <- names(sort(digit_freq, decreasing = TRUE))[1:2]
      results$digit_preference <- list(
        severity = "low", type = "distribution",
        suggestion = switch(lang,
                            de = paste0("Ziffernpräferenz erkannt (Endung ", paste(top_digits, collapse = ","),
                                        " überrepräsentiert). Hinweis auf Rundung oder Schätzung."),
                            fr = paste0("Préférence de chiffres (terminaison ", paste(top_digits, collapse = ","),
                                        " surreprésentée). Arrondi ou estimation probable."),
                            paste0("Digit preference detected (ending ", paste(top_digits, collapse = ","),
                                   " overrepresented). Indicates rounding or estimation.")),
        correction = "Informational; consider noting in methods section"
      )
    }
    
    # Suspicious spikes (single value > 20% of data, not the mode of a genuine categorical)
    val_freq <- sort(table(valid), decreasing = TRUE)
    if (length(val_freq) > 5) {
      top_pct <- val_freq[1] / n_valid
      if (top_pct > 0.20) {
        spike_val <- as.numeric(names(val_freq)[1])
        spike_idx <- which(num_vals == spike_val & !is.na(num_vals))
        results$value_spike <- list(
          rows = spike_idx, values = rep(spike_val, length(spike_idx)),
          severity = "medium", type = "distribution",
          suggestion = switch(lang,
                              de = paste0("Werteanhäufung: ", round(top_pct*100,1), "% der Werte = ", spike_val,
                                          ". Möglicher Default-/Platzhalterwert."),
                              fr = paste0("Concentration: ", round(top_pct*100,1), "% des valeurs = ", spike_val, "."),
                              paste0("Value spike: ", round(top_pct*100,1), "% of values = ", spike_val,
                                     ". Possible default/placeholder value.")),
          correction = paste0("Verify if ", spike_val, " is a genuine value or a system default")
        )
      }
    }
  }
  
  # ── 5. Negative values where only positive expected ─────────────────────
  if (grepl("count|anzahl|nombre|duration|dauer|durée|los|length.?of.?stay|cost|kosten|coût|days|tage|jours",
            col_lower)) {
    neg_idx <- which(!is.na(num_vals) & num_vals < 0)
    if (length(neg_idx) > 0) {
      results$unexpected_negative <- list(
        rows = neg_idx, values = num_vals[neg_idx],
        severity = "high", type = "impossible_value",
        suggestion = switch(lang,
                            de = paste0(length(neg_idx), " negative Werte in '", col_name, "' (erwartet: ≥ 0)."),
                            fr = paste0(length(neg_idx), " valeurs négatives dans '", col_name, "'."),
                            paste0(length(neg_idx), " negative values in '", col_name, "' (expected ≥ 0).")),
        correction = "Replace with absolute value or investigate sign error"
      )
    }
  }
  
  # ── 6. Missing values summary ───────────────────────────────────────────
  na_count <- sum(is.na(num_vals) | is.na(vals) | as.character(vals) %in% c("", "NA", "na", "N/A", "n/a", "NULL", "null", "."))
  if (na_count > 0) {
    results$missing <- list(
      count = na_count,
      pct   = round(100 * na_count / length(vals), 1),
      severity = if (na_count / length(vals) > 0.3) "high" else if (na_count / length(vals) > 0.1) "medium" else "low",
      type  = "missing",
      suggestion = switch(lang,
                          de = paste0(na_count, " fehlende Werte (", round(100 * na_count / length(vals), 1), "%)."),
                          fr = paste0(na_count, " valeurs manquantes (", round(100 * na_count / length(vals), 1), "%)."),
                          paste0(na_count, " missing values (", round(100 * na_count / length(vals), 1), "%).")),
      correction = switch(lang,
                          de = paste0("Median-Imputation: ", round(med, 2), " | Oder: NA belassen und in Analyse berücksichtigen"),
                          fr = paste0("Imputation par médiane: ", round(med, 2)),
                          paste0("Median imputation: ", round(med, 2), " | Or: keep NA and handle in analysis"))
    )
  }
  
  results
}


# ── ML: Date/Timestamp Anomaly Detection ─────────────────────────────────────

ai_date_anomalies <- function(vals, col_name, lang = "en") {
  results <- list()
  
  vals_chr <- trimws(as.character(vals))
  vals_chr[vals_chr %in% c("", "NA", "na", "NULL", "null", ".")] <- NA
  
  # Try multiple date formats
  parsed <- suppressWarnings(as.Date(vals_chr))
  if (sum(!is.na(parsed)) < length(vals_chr) * 0.5) {
    for (fmt in c("%d.%m.%Y", "%d/%m/%Y", "%m/%d/%Y", "%d-%m-%Y", "%Y%m%d", "%d.%m.%y", "%m-%d-%Y")) {
      attempt <- suppressWarnings(as.Date(vals_chr, format = fmt))
      if (sum(!is.na(attempt)) > sum(!is.na(parsed))) {
        parsed <- attempt
        results$format_detected <- list(
          severity = "low", type = "format",
          suggestion = switch(lang,
                              de = paste0("Datumsformat erkannt: ", fmt, ". Standardisierung auf YYYY-MM-DD empfohlen."),
                              fr = paste0("Format détecté: ", fmt, ". Standardisation AAAA-MM-JJ recommandée."),
                              paste0("Date format detected: ", fmt, ". Standardization to YYYY-MM-DD recommended.")),
          correction = paste0("Use format: ", fmt, " → convert to ISO 8601")
        )
      }
    }
  }
  
  valid_dates <- parsed[!is.na(parsed)]
  n_valid     <- length(valid_dates)
  
  # Unparseable dates
  unparseable_idx <- which(!is.na(vals_chr) & nzchar(vals_chr) & is.na(parsed))
  if (length(unparseable_idx) > 0) {
    results$unparseable <- list(
      rows     = unparseable_idx,
      values   = vals_chr[unparseable_idx],
      severity = "high",
      type     = "format_error",
      suggestion = switch(lang,
                          de = paste0(length(unparseable_idx), " nicht parsbare Datumsangaben. Manuelles Format prüfen."),
                          fr = paste0(length(unparseable_idx), " dates non analysables."),
                          paste0(length(unparseable_idx), " unparseable date values. Check format manually.")),
      correction = "Inspect values; may need manual correction or different format specification"
    )
  }
  
  if (n_valid < 3) return(results)
  
  # ── Future dates ────────────────────────────────────────────────────────
  today <- Sys.Date()
  future_idx <- which(!is.na(parsed) & parsed > today)
  if (length(future_idx) > 0) {
    results$future_dates <- list(
      rows = future_idx, values = as.character(parsed[future_idx]),
      severity = "high", type = "temporal",
      suggestion = switch(lang,
                          de = paste0(length(future_idx), " Daten liegen in der Zukunft."),
                          fr = paste0(length(future_idx), " dates dans le futur."),
                          paste0(length(future_idx), " dates are in the future.")),
      correction = "Verify data entry; likely recording errors"
    )
  }
  
  # ── Implausibly old dates ───────────────────────────────────────────────
  old_threshold <- as.Date("1900-01-01")
  old_idx <- which(!is.na(parsed) & parsed < old_threshold)
  if (length(old_idx) > 0) {
    results$ancient_dates <- list(
      rows = old_idx, values = as.character(parsed[old_idx]),
      severity = "high", type = "temporal",
      suggestion = switch(lang,
                          de = paste0(length(old_idx), " Daten vor 1900 – wahrscheinlich Eingabefehler."),
                          fr = paste0(length(old_idx), " dates avant 1900."),
                          paste0(length(old_idx), " dates before 1900 – likely entry errors.")),
      correction = "Check for year-only entries or century errors (e.g., 0024 vs 2024)"
    )
  }
  
  # ── Temporal outliers (IQR on numeric date) ─────────────────────────────
  date_num <- as.numeric(valid_dates)
  q1 <- quantile(date_num, 0.25); q3 <- quantile(date_num, 0.75)
  iqr <- q3 - q1
  if (iqr > 0) {
    lower <- q1 - 3 * iqr; upper <- q3 + 3 * iqr
    outlier_idx <- which(!is.na(parsed) & (as.numeric(parsed) < lower | as.numeric(parsed) > upper))
    outlier_idx <- setdiff(outlier_idx, c(future_idx, old_idx))
    if (length(outlier_idx) > 0 && length(outlier_idx) <= n_valid * 0.05) {
      results$date_outliers <- list(
        rows = outlier_idx, values = as.character(parsed[outlier_idx]),
        severity = "medium", type = "temporal_outlier",
        suggestion = switch(lang,
                            de = paste0(length(outlier_idx), " zeitliche Ausreißer (>3×IQR vom Zentrum)."),
                            fr = paste0(length(outlier_idx), " dates aberrantes."),
                            paste0(length(outlier_idx), " temporal outliers (>3×IQR from center).")),
        correction = "Verify against expected study period"
      )
    }
  }
  
  # ── Duplicate timestamps (exact same date suspiciously common) ──────────
  date_freq <- sort(table(valid_dates), decreasing = TRUE)
  if (length(date_freq) > 3) {
    top_pct <- date_freq[1] / n_valid
    if (top_pct > 0.15 && n_valid > 20) {
      results$date_spike <- list(
        severity = "medium", type = "distribution",
        suggestion = switch(lang,
                            de = paste0(round(top_pct*100,1), "% aller Daten = ", names(date_freq)[1],
                                        ". Möglicher Standardwert."),
                            fr = paste0(round(top_pct*100,1), "% des dates = ", names(date_freq)[1], "."),
                            paste0(round(top_pct*100,1), "% of dates = ", names(date_freq)[1],
                                   ". Possible default/placeholder.")),
        correction = paste0("Check if '", names(date_freq)[1], "' is a system default date")
      )
    }
  }
  
  # ── Mixed formats ───────────────────────────────────────────────────────
  has_iso   <- sum(grepl("^\\d{4}-\\d{2}-\\d{2}", vals_chr[!is.na(vals_chr)]))
  has_euro  <- sum(grepl("^\\d{2}\\.\\d{2}\\.\\d{4}", vals_chr[!is.na(vals_chr)]))
  has_us    <- sum(grepl("^\\d{2}/\\d{2}/\\d{4}", vals_chr[!is.na(vals_chr)]))
  formats_present <- sum(c(has_iso, has_euro, has_us) > 0)
  if (formats_present > 1) {
    results$mixed_formats <- list(
      severity = "high", type = "format_inconsistency",
      suggestion = switch(lang,
                          de = "Gemischte Datumsformate erkannt (ISO + EU oder US). Standardisierung dringend empfohlen.",
                          fr = "Formats de dates mélangés détectés. Standardisation urgente.",
                          "Mixed date formats detected (ISO + European or US). Standardization strongly recommended."),
      correction = "Use the 'Fix Date Format' tool to standardize all dates"
    )
  }
  
  # ── Missing ─────────────────────────────────────────────────────────────
  na_count <- sum(is.na(vals) | vals_chr %in% c("", "NA", "na", "NULL", "null", ".") | is.na(vals_chr))
  if (na_count > 0) {
    results$missing <- list(
      count = na_count, pct = round(100 * na_count / length(vals), 1),
      severity = if (na_count / length(vals) > 0.3) "high" else "low",
      type = "missing",
      suggestion = switch(lang,
                          de = paste0(na_count, " fehlende Datumswerte (", round(100 * na_count / length(vals), 1), "%)."),
                          fr = paste0(na_count, " dates manquantes."),
                          paste0(na_count, " missing date values (", round(100 * na_count / length(vals), 1), "%).")),
      correction = "Investigate whether dates are available from source system"
    )
  }
  
  results
}


# ── ML: Categorical/String Anomaly Detection ─────────────────────────────────
# Uses frequency analysis, Levenshtein distance for typo detection,
# encoding checks, whitespace/casing inconsistencies.

ai_categorical_anomalies <- function(vals, col_name, lang = "en") {
  results <- list()
  vals_chr <- as.character(vals)
  non_na   <- vals_chr[!is.na(vals_chr) & nzchar(trimws(vals_chr))]
  n_total  <- length(vals)
  n_valid  <- length(non_na)
  if (n_valid < 3) return(results)
  
  freq <- sort(table(non_na), decreasing = TRUE)
  n_unique <- length(freq)
  
  # ── 1. Rare values / potential typos ────────────────────────────────────
  if (n_unique >= 3 && n_unique <= 200) {
    rare_threshold <- max(1, n_valid * 0.01)
    rare_vals  <- names(freq[freq <= rare_threshold])
    common_vals <- names(freq[freq > rare_threshold])
    
    if (length(rare_vals) > 0 && length(rare_vals) < 30 && length(common_vals) > 0) {
      # Levenshtein-based typo detection
      typo_suggestions <- list()
      for (rv_val in rare_vals) {
        dists <- vapply(common_vals, function(cv) {
          utils::adist(tolower(rv_val), tolower(cv))[1, 1]
        }, numeric(1))
        best_match <- common_vals[which.min(dists)]
        best_dist  <- min(dists)
        # Typo threshold: edit distance 1-2 for short strings, 1-3 for longer
        max_dist <- if (nchar(rv_val) <= 5) 1 else if (nchar(rv_val) <= 10) 2 else 3
        if (best_dist <= max_dist && best_dist > 0) {
          typo_suggestions[[rv_val]] <- list(
            rare_value = rv_val,
            suggested  = best_match,
            distance   = best_dist,
            freq_rare  = as.integer(freq[rv_val]),
            freq_match = as.integer(freq[best_match])
          )
        }
      }
      
      if (length(typo_suggestions) > 0) {
        typo_rows <- which(vals_chr %in% names(typo_suggestions))
        desc_parts <- vapply(typo_suggestions, function(ts) {
          paste0("'", ts$rare_value, "' → '", ts$suggested, "' (", ts$freq_rare, "× vs ", ts$freq_match, "×)")
        }, character(1))
        results$typos <- list(
          rows = typo_rows,
          values = vals_chr[typo_rows],
          severity = "high",
          type = "typo",
          details = typo_suggestions,
          suggestion = switch(lang,
                              de = paste0(length(typo_suggestions), " wahrscheinliche Tippfehler: ", paste(desc_parts, collapse = "; ")),
                              fr = paste0(length(typo_suggestions), " fautes de frappe probables: ", paste(desc_parts, collapse = "; ")),
                              paste0(length(typo_suggestions), " likely typos detected: ", paste(desc_parts, collapse = "; "))),
          correction = "Use Find & Replace to correct each typo"
        )
      }
      
      # Rare values that are NOT typos (genuine rare values)
      non_typo_rare <- setdiff(rare_vals, names(typo_suggestions))
      if (length(non_typo_rare) > 0 && length(non_typo_rare) < 20) {
        results$rare_values <- list(
          rows = which(vals_chr %in% non_typo_rare),
          values = vals_chr[which(vals_chr %in% non_typo_rare)],
          severity = "low",
          type = "rare",
          suggestion = switch(lang,
                              de = paste0(length(non_typo_rare), " seltene Werte (< 1%): ", paste(non_typo_rare[1:min(5, length(non_typo_rare))], collapse = ", ")),
                              fr = paste0(length(non_typo_rare), " valeurs rares: ", paste(non_typo_rare[1:min(5, length(non_typo_rare))], collapse = ", ")),
                              paste0(length(non_typo_rare), " rare values (< 1%): ", paste(non_typo_rare[1:min(5, length(non_typo_rare))], collapse = ", "))),
          correction = "Review if these are valid categories or need standardization"
        )
      }
    }
  }
  
  # ── 2. Case inconsistencies ─────────────────────────────────────────────
  lower_vals  <- tolower(non_na)
  lower_unique <- unique(lower_vals)
  if (length(lower_unique) < n_unique) {
    # Find case-inconsistent groups
    case_groups <- list()
    for (lu in lower_unique) {
      orig_forms <- unique(non_na[lower_vals == lu])
      if (length(orig_forms) > 1) {
        case_groups[[lu]] <- orig_forms
      }
    }
    if (length(case_groups) > 0) {
      affected_vals <- unlist(lapply(case_groups, function(g) g[-1]))  # all but most common
      affected_rows <- which(vals_chr %in% affected_vals)
      desc <- paste(vapply(case_groups[1:min(5, length(case_groups))], function(g) {
        paste0("{", paste(g, collapse = ", "), "}")
      }, character(1)), collapse = "; ")
      results$case_inconsistency <- list(
        rows = affected_rows,
        severity = "medium",
        type = "casing",
        details = case_groups,
        suggestion = switch(lang,
                            de = paste0(length(case_groups), " Groß-/Kleinschreibungskonflikte: ", desc),
                            fr = paste0(length(case_groups), " incohérences de casse: ", desc),
                            paste0(length(case_groups), " case inconsistencies: ", desc)),
        correction = "Standardize to one casing per category"
      )
    }
  }
  
  # ── 3. Whitespace issues ────────────────────────────────────────────────
  leading  <- which(grepl("^\\s", vals_chr) & !is.na(vals_chr))
  trailing <- which(grepl("\\s$", vals_chr) & !is.na(vals_chr))
  double_sp <- which(grepl("\\s{2,}", vals_chr) & !is.na(vals_chr))
  ws_issues <- unique(c(leading, trailing, double_sp))
  if (length(ws_issues) > 0) {
    results$whitespace <- list(
      rows = ws_issues,
      severity = "medium",
      type = "whitespace",
      suggestion = switch(lang,
                          de = paste0(length(ws_issues), " Werte mit führenden/trailing/doppelten Leerzeichen."),
                          fr = paste0(length(ws_issues), " valeurs avec espaces superflus."),
                          paste0(length(ws_issues), " values with leading/trailing/double whitespace.")),
      correction = "Trim whitespace (Find & Replace: regex '\\s+' → ' ', then trim)"
    )
  }
  
  # ── 4. Encoding issues ─────────────────────────────────────────────────
  encoding_idx <- which(grepl("\xc3\x83|\xc2\xa4|\xc2\xb6|\xc2\xbc|\\\\u00|\xc3\x84|\xc3\x96|\xc3\x9c|\xc3\x9f|\xe2\x80", vals_chr, useBytes = TRUE) & !is.na(vals_chr))
  if (length(encoding_idx) > 0) {    
    results$encoding <- list(
      rows = encoding_idx,
      values = vals_chr[encoding_idx][1:min(5, length(encoding_idx))],
      severity = "high",
      type = "encoding",
      suggestion = switch(lang,
                          de = paste0(length(encoding_idx), " Werte mit Encoding-Problemen (UTF-8/Latin-1 Mismatch)."),
                          fr = paste0(length(encoding_idx), " problèmes d'encodage détectés."),
                          paste0(length(encoding_idx), " values with encoding issues (UTF-8/Latin-1 mismatch).")),
      correction = "Re-import with correct encoding, or use Find & Replace to fix characters"
    )
  }
  
  # ── 5. Empty string vs NA inconsistency ─────────────────────────────────
  na_like <- c("", "NA", "na", "N/A", "n/a", "NULL", "null", ".", "-", "none", "None", "NONE",
               "missing", "Missing", "unknown", "Unknown", "UNKNOWN", "k.A.", "nb", "ND")
  na_like_idx <- which(vals_chr %in% na_like)
  real_na_idx <- which(is.na(vals))
  if (length(na_like_idx) > 0 && length(real_na_idx) > 0) {
    # Both real NAs and NA-like strings exist → inconsistent missing representation
    results$na_inconsistency <- list(
      rows = na_like_idx,
      values = vals_chr[na_like_idx],
      severity = "medium",
      type = "missing_representation",
      suggestion = switch(lang,
                          de = paste0(length(na_like_idx), " NA-ähnliche Strings neben echten NAs. Standardisierung empfohlen."),
                          fr = paste0(length(na_like_idx), " chaînes NA-like à côté de vrais NA."),
                          paste0(length(na_like_idx), " NA-like strings alongside real NAs. Standardize missing representation.")),
      correction = "Convert all NA-like values to proper NA"
    )
  } else if (length(na_like_idx) > 0) {
    results$na_strings <- list(
      rows = na_like_idx, severity = "low", type = "missing_representation",
      suggestion = switch(lang,
                          de = paste0(length(na_like_idx), " NA-ähnliche Strings gefunden."),
                          fr = paste0(length(na_like_idx), " chaînes NA-like."),
                          paste0(length(na_like_idx), " NA-like string values found.")),
      correction = "Convert to proper NA for consistent handling"
    )
  }
  
  # ── 6. Overall missing ─────────────────────────────────────────────────
  total_missing <- length(real_na_idx) + length(na_like_idx)
  if (total_missing > 0) {
    results$missing <- list(
      count = total_missing,
      pct = round(100 * total_missing / n_total, 1),
      severity = if (total_missing / n_total > 0.3) "high" else if (total_missing / n_total > 0.1) "medium" else "low",
      type = "missing",
      suggestion = switch(lang,
                          de = paste0(total_missing, " fehlende Werte insgesamt (", round(100 * total_missing / n_total, 1), "%)."),
                          fr = paste0(total_missing, " valeurs manquantes au total."),
                          paste0(total_missing, " total missing values (", round(100 * total_missing / n_total, 1), "%).")),
      correction = "Decide: impute mode, keep as NA, or investigate source"
    )
  }
  
  results
}


# ── ML: Free-text Anomaly Detection ──────────────────────────────────────────

ai_text_anomalies <- function(vals, col_name, lang = "en") {
  results <- list()
  vals_chr <- as.character(vals)
  non_na   <- vals_chr[!is.na(vals_chr) & nzchar(trimws(vals_chr))]
  n_valid  <- length(non_na)
  if (n_valid < 3) return(results)
  
  lengths <- nchar(non_na)
  
  # ── 1. Suspiciously short texts ─────────────────────────────────────────
  med_len <- median(lengths)
  if (med_len > 20) {
    very_short <- which(!is.na(vals_chr) & nzchar(trimws(vals_chr)) & nchar(vals_chr) < max(5, med_len * 0.1))
    if (length(very_short) > 0 && length(very_short) < n_valid * 0.1) {
      results$short_texts <- list(
        rows = very_short, values = vals_chr[very_short],
        severity = "low", type = "length_outlier",
        suggestion = switch(lang,
                            de = paste0(length(very_short), " ungewöhnlich kurze Texte (Median: ", round(med_len), " Zeichen)."),
                            fr = paste0(length(very_short), " textes inhabituellement courts."),
                            paste0(length(very_short), " unusually short texts (median: ", round(med_len), " chars).")),
        correction = "May be placeholders or incomplete entries"
      )
    }
  }
  
  # ── 2. Exact duplicates (copy-paste) ────────────────────────────────────
  if (n_valid > 10 && med_len > 50) {
    dup_table <- table(non_na)
    repeated  <- names(dup_table[dup_table > 1 & dup_table > n_valid * 0.05])
    if (length(repeated) > 0) {
      dup_idx <- which(vals_chr %in% repeated)
      results$copy_paste <- list(
        rows = dup_idx, severity = "medium", type = "duplicate_text",
        suggestion = switch(lang,
                            de = paste0(length(repeated), " identische Langtexte wiederholt. Mögliches Copy-Paste."),
                            fr = paste0(length(repeated), " textes longs identiques. Copier-coller possible."),
                            paste0(length(repeated), " identical long texts repeated. Possible copy-paste.")),
        correction = "Verify if duplicate text entries are intentional"
      )
    }
  }
  
  # ── 3. Test/placeholder patterns ────────────────────────────────────────
  test_patterns <- c("test", "xxx", "asdf", "placeholder", "todo", "fixme",
                     "dummy", "sample", "example", "lorem", "tbd", "n/a")
  test_idx <- which(vapply(vals_chr, function(v) {
    any(vapply(test_patterns, function(p) grepl(p, tolower(v), fixed = TRUE), logical(1)))
  }, logical(1)))
  if (length(test_idx) > 0) {
    results$test_data <- list(
      rows = test_idx, values = vals_chr[test_idx],
      severity = "high", type = "test_data",
      suggestion = switch(lang,
                          de = paste0(length(test_idx), " mögliche Test-/Platzhalterdaten gefunden."),
                          fr = paste0(length(test_idx), " données de test/placeholder possibles."),
                          paste0(length(test_idx), " possible test/placeholder entries found.")),
      correction = "Remove or replace with actual data"
    )
  }
  
  # ── 4. Missing ─────────────────────────────────────────────────────────
  na_count <- sum(is.na(vals_chr) | !nzchar(trimws(vals_chr)))
  if (na_count > 0) {
    results$missing <- list(
      count = na_count, pct = round(100 * na_count / length(vals), 1),
      severity = if (na_count / length(vals) > 0.5) "high" else "low",
      type = "missing",
      suggestion = paste0(na_count, switch(lang, de = " fehlende Texteinträge.", fr = " textes manquants.", " missing text entries.")),
      correction = "Assess if text field is optional or required for your study"
    )
  }
  
  results
}


# ── ML: ICD/OPS Code Anomaly Detection ───────────────────────────────────────

ai_code_anomalies <- function(vals, col_name, code_type = "icd", lang = "en") {
  results <- list()
  vals_chr <- trimws(as.character(vals))
  non_na   <- vals_chr[!is.na(vals_chr) & nzchar(vals_chr)]
  n_valid  <- length(non_na)
  if (n_valid < 3) return(results)
  
  if (code_type == "icd") {
    # Split multi-codes
    all_tokens <- unlist(strsplit(toupper(gsub("\\s+", "", non_na)), "[;,|/]+"))
    all_tokens <- all_tokens[nzchar(all_tokens)]
    
    valid_pattern <- "^[A-Z][0-9]{2}(\\.[0-9A-Z]{1,4})?$"
    invalid <- all_tokens[!grepl(valid_pattern, all_tokens)]
    
    if (length(invalid) > 0) {
      # Find which rows contain invalid tokens
      invalid_rows <- which(vapply(vals_chr, function(v) {
        tokens <- unlist(strsplit(toupper(gsub("\\s+", "", v)), "[;,|/]+"))
        any(!grepl(valid_pattern, tokens[nzchar(tokens)]))
      }, logical(1)))
      
      results$invalid_codes <- list(
        rows = invalid_rows, values = unique(invalid)[1:min(10, length(unique(invalid)))],
        severity = "high", type = "invalid_code",
        suggestion = switch(lang,
                            de = paste0(length(unique(invalid)), " ungültige ICD-Code-Formate: ", paste(unique(invalid)[1:min(5, length(unique(invalid)))], collapse = ", ")),
                            fr = paste0(length(unique(invalid)), " codes CIM invalides."),
                            paste0(length(unique(invalid)), " invalid ICD code formats: ", paste(unique(invalid)[1:min(5, length(unique(invalid)))], collapse = ", "))),
        correction = "Check for ICD-9 codes, typos, or encoding issues"
      )
    }
    
    # Unspecific codes
    unspec <- all_tokens[grepl("^[A-Z][0-9]{2}$", all_tokens) & !grepl("^(R99|Z00)$", all_tokens)]
    if (length(unspec) > length(all_tokens) * 0.3 && length(all_tokens) > 10) {
      results$unspecific <- list(
        severity = "medium", type = "code_quality",
        suggestion = switch(lang,
                            de = paste0(round(100 * length(unspec) / length(all_tokens)), "% der ICD-Codes ohne Dezimalstelle. Niedrige Spezifität."),
                            fr = paste0(round(100 * length(unspec) / length(all_tokens)), "% des codes sans décimale."),
                            paste0(round(100 * length(unspec) / length(all_tokens)), "% of ICD codes lack decimal specificity.")),
        correction = "Consider if more specific coding is available from source"
      )
    }
  }
  
  if (code_type == "ops") {
    all_tokens <- unlist(strsplit(toupper(gsub("[\\s\u2013\u2014]", "", non_na)), "[;,|/]+"))
    all_tokens <- all_tokens[nzchar(all_tokens)]
    valid_pattern <- "^[0-9]-[0-9]{2,3}(\\.[0-9A-Z]{1,3}){0,2}$"
    invalid <- all_tokens[!grepl(valid_pattern, all_tokens)]
    
    if (length(invalid) > 0) {
      invalid_rows <- which(vapply(vals_chr, function(v) {
        tokens <- unlist(strsplit(toupper(gsub("[\\s\u2013\u2014]", "", v)), "[;,|/]+"))
        any(!grepl(valid_pattern, tokens[nzchar(tokens)]))
      }, logical(1)))
      results$invalid_ops <- list(
        rows = invalid_rows, values = unique(invalid)[1:min(10, length(unique(invalid)))],
        severity = "high", type = "invalid_code",
        suggestion = switch(lang,
                            de = paste0(length(unique(invalid)), " ungültige OPS-Formate."),
                            fr = paste0(length(unique(invalid)), " formats OPS invalides."),
                            paste0(length(unique(invalid)), " invalid OPS code formats.")),
        correction = "Check for missing hyphens or wrong structure"
      )
    }
  }
  
  results
}


# ═══════════════════════════════════════════════════════════════════════════════
# MASTER FUNCTION: ai_detect_anomalies_v2
# Automatically selects the right ML method per column type.
# ═══════════════════════════════════════════════════════════════════════════════

ai_detect_anomalies <- function(df, col_name, lang = "en") {
  if (!col_name %in% names(df)) return(NULL)
  vals <- df[[col_name]]
  
  # Step 1: Classify column type
  col_type <- ai_type_classifier(vals)
  
  # Step 2: Route to appropriate detector
  results <- switch(col_type,
                    "numeric"     = ai_numeric_anomalies(vals, col_name, lang),
                    "integer"     = ai_numeric_anomalies(vals, col_name, lang),
                    "date"        = ai_date_anomalies(vals, col_name, lang),
                    "datetime"    = ai_date_anomalies(vals, col_name, lang),
                    "categorical" = ai_categorical_anomalies(vals, col_name, lang),
                    "binary"      = ai_categorical_anomalies(vals, col_name, lang),
                    "code_icd"    = ai_code_anomalies(vals, col_name, "icd", lang),
                    "code_ops"    = ai_code_anomalies(vals, col_name, "ops", lang),
                    "freetext"    = ai_text_anomalies(vals, col_name, lang),
                    "id"          = {
                      # For ID columns: only check duplicates and missing
                      res <- list()
                      dup_idx <- which(duplicated(vals) & !is.na(vals))
                      if (length(dup_idx) > 0) {
                        res$duplicate_ids <- list(
                          rows = dup_idx, values = as.character(vals[dup_idx]),
                          severity = "high", type = "duplicate",
                          suggestion = switch(lang,
                                              de = paste0(length(dup_idx), " doppelte IDs."),
                                              fr = paste0(length(dup_idx), " IDs en double."),
                                              paste0(length(dup_idx), " duplicate IDs.")),
                          correction = "Deduplicate or investigate data merging issues"
                        )
                      }
                      na_c <- sum(is.na(vals) | as.character(vals) %in% c("", "NA"))
                      if (na_c > 0) res$missing_ids <- list(
                        count = na_c, severity = "high", type = "missing",
                        suggestion = paste0(na_c, switch(lang, de = " fehlende IDs.", fr = " IDs manquants.", " missing IDs.")),
                        correction = "IDs should never be missing"
                      )
                      res
                    },
                    "mixed"       = c(ai_numeric_anomalies(vals, col_name, lang),
                                      ai_categorical_anomalies(vals, col_name, lang)),
                    "empty"       = list(empty = list(severity = "high", type = "empty",
                                                      suggestion = switch(lang,
                                                                          de = "Spalte ist vollständig leer.",
                                                                          fr = "Colonne entièrement vide.",
                                                                          "Column is completely empty."),
                                                      correction = "Remove column or investigate data source")),
                    # fallback
                    ai_categorical_anomalies(vals, col_name, lang)
  )
  
  # Add metadata about detected type
  if (length(results) > 0) {
    attr(results, "detected_type") <- col_type
  }
  
  results
}

# ══════════════════════════════════════════════════════════════════════════════
# V.0.1: ADVANCED CROSS-COLUMN ML INTELLIGENCE ENGINE
# Discovers complex quality problems researchers typically overlook:
#   - Suspicious numeric correlations / anti-correlations
#   - Conditional missing-data patterns (MAR indicators)
#   - Value-dependency violations (cross-column business rules)
#   - Multi-column duplicate fingerprint detection
#   - Benford's Law deviation (data fabrication indicator)
#   - Entropy anomalies (constant columns, suspiciously uniform distributions)
#   - Date-column chronological ordering violations
# All functions are performant (vectorized, sampled) and use only base R + stats.
# ══════════════════════════════════════════════════════════════════════════════

# ── Suspicious Numeric Correlations ──────────────────────────────────────────
# Detects column pairs with unexpectedly extreme correlations (>0.95 or < -0.85)
# that often indicate data duplication, unit confusion, or formula residuals.
ai_cross_correlation <- function(df, num_cols, lang = "en", max_pairs = 50) {
  results <- list()
  if (length(num_cols) < 2) return(results)
  
  # Limit combinatorial explosion: prioritize columns with fewest NAs
  na_rates <- vapply(num_cols, function(cn) mean(is.na(df[[cn]])), numeric(1))
  num_cols <- num_cols[order(na_rates)]
  if (length(num_cols) > 12) num_cols <- num_cols[1:12]
  
  pairs_checked <- 0L
  for (i in seq_along(num_cols)[-length(num_cols)]) {
    for (j in (i + 1):length(num_cols)) {
      if (pairs_checked >= max_pairs) break
      cn_a <- num_cols[i]; cn_b <- num_cols[j]
      a <- suppressWarnings(as.numeric(df[[cn_a]]))
      b <- suppressWarnings(as.numeric(df[[cn_b]]))
      ok <- is.finite(a) & is.finite(b)
      if (sum(ok) < 30) next
      
      r <- tryCatch(cor(a[ok], b[ok], method = "spearman"), error = function(e) NA_real_)
      if (is.na(r)) next
      pairs_checked <- pairs_checked + 1L
      
      # Near-perfect positive correlation (possible duplication / derived column)
      if (abs(r) > 0.95) {
        sym_a <- safe_sym(cn_a); sym_b <- safe_sym(cn_b)
        sev <- if (abs(r) > 0.99) "High" else "Medium"
        direction <- if (r > 0) "positive" else "negative"
        results[[length(results) + 1]] <- list(
          name = paste0("Correlation anomaly: ", cn_a, " \u2194 ", cn_b),
          desc = switch(lang,
                        de = paste0("Spearman-Korrelation r=", round(r, 3), " zwischen '", cn_a, "' und '", cn_b, "'. M\u00f6gliche Duplikation, Einheitenverwechslung oder abgeleitete Spalte."),
                        fr = paste0("Corr\u00e9lation de Spearman r=", round(r, 3), " entre '", cn_a, "' et '", cn_b, "'. Duplication possible, confusion d'unit\u00e9s ou colonne d\u00e9riv\u00e9e."),
                        paste0("Spearman correlation r=", round(r, 3), " between '", cn_a, "' and '", cn_b, "'. Possible duplication, unit confusion, or derived column.")),
          reason = paste0("|r| = ", round(abs(r), 3), " (", direction, "). n=", sum(ok), " complete pairs. Threshold: |r|>0.95."),
          sev = sev,
          expr = paste0("({.a<-as.numeric(", sym_a, "); .b<-as.numeric(", sym_b, "); .ok<-is.finite(.a)&is.finite(.b); .r<-rep(FALSE,length(.a)); if(sum(.ok)>=10){.res<-abs(.a[.ok]-.b[.ok]); .r[.ok]<-.res<(0.01*max(abs(c(.a[.ok],.b[.ok])),na.rm=TRUE))}; .r})"),
          col = paste0(cn_a, " \u2194 ", cn_b),
          op = "CORRELATION", val = paste0("r=", round(r, 3)),
          cross = TRUE
        )
      }
      
      # Strong negative correlation (possible inverse coding or error)
      if (r < -0.85 && abs(r) <= 0.95) {
        sym_a <- safe_sym(cn_a); sym_b <- safe_sym(cn_b)
        results[[length(results) + 1]] <- list(
          name = paste0("Inverse relationship: ", cn_a, " \u2194 ", cn_b),
          desc = switch(lang,
                        de = paste0("Starke negative Korrelation r=", round(r, 3), " zwischen '", cn_a, "' und '", cn_b, "'. Pr\u00fcfen Sie auf Vorzeichenfehler oder inverse Codierung."),
                        fr = paste0("Forte corr\u00e9lation n\u00e9gative r=", round(r, 3), " entre '", cn_a, "' et '", cn_b, "'. V\u00e9rifiez les erreurs de signe ou le codage inverse."),
                        paste0("Strong negative correlation r=", round(r, 3), " between '", cn_a, "' and '", cn_b, "'. Check for sign errors or inverse coding.")),
          reason = paste0("r = ", round(r, 3), ". In clinical data, strong negative correlations are uncommon and may indicate coding problems."),
          sev = "Medium",
          expr = "FALSE",
          col = paste0(cn_a, " \u2194 ", cn_b),
          op = "INVERSE_CORR", val = paste0("r=", round(r, 3)),
          cross = TRUE
        )
      }
    }
    if (pairs_checked >= max_pairs) break
  }
  results
}

# ── Conditional Missing Patterns (MAR Detection) ────────────────────────────
# Detects when missingness in column B is strongly predicted by values in
# column A — a marker of Missing At Random (MAR) which biases analysis.
ai_cross_missing_pattern <- function(df, cols, lang = "en") {
  results <- list()
  if (length(cols) < 2) return(results)
  
  # Focus on columns that have some (but not all) missingness
  miss_rates <- vapply(cols, function(cn) mean(is_blank(df[[cn]])), numeric(1))
  target_cols <- cols[miss_rates > 0.02 & miss_rates < 0.90]
  predictor_cols <- cols[miss_rates < 0.50]
  
  if (length(target_cols) == 0 || length(predictor_cols) == 0) return(results)
  
  # Limit scope
  if (length(target_cols) > 6) target_cols <- target_cols[order(-miss_rates[target_cols])][1:6]
  if (length(predictor_cols) > 10) predictor_cols <- predictor_cols[1:10]
  
  for (tgt in target_cols) {
    tgt_missing <- is_blank(df[[tgt]])
    for (pred in predictor_cols) {
      if (pred == tgt) next
      pred_vals <- df[[pred]]
      # Only test categorical predictors (or discretized numerics)
      if (is.numeric(pred_vals)) {
        if (length(unique(pred_vals[!is.na(pred_vals)])) > 20) next
      }
      pred_fac <- as.character(pred_vals)
      pred_fac[is.na(pred_fac) | !nzchar(trimws(pred_fac))] <- "__NA__"
      
      # Chi-squared test of independence between pred groups and missingness
      tbl <- tryCatch({
        tab <- table(pred_fac, tgt_missing)
        if (ncol(tab) < 2 || nrow(tab) < 2) NULL
        else if (any(tab < 0)) NULL
        else tab
      }, error = function(e) NULL)
      
      if (is.null(tbl)) next
      
      chi <- tryCatch(chisq.test(tbl, simulate.p.value = TRUE, B = 500),
                      error = function(e) NULL)
      if (is.null(chi)) next
      if (chi$p.value >= 0.001) next  # only flag strong associations
      
      # Compute effect size (Cramér's V)
      n_obs <- sum(tbl)
      k <- min(nrow(tbl), ncol(tbl))
      cramers_v <- tryCatch(sqrt(chi$statistic / (n_obs * (k - 1))), error = function(e) 0)
      if (is.na(cramers_v) || cramers_v < 0.25) next
      
      # Identify which predictor value has highest missingness
      miss_by_group <- tapply(tgt_missing, pred_fac, mean, default = 0)
      worst_group <- names(which.max(miss_by_group))
      worst_rate <- max(miss_by_group, na.rm = TRUE)
      
      sym_tgt <- safe_sym(tgt); sym_pred <- safe_sym(pred)
      worst_safe <- gsub('"', '\\\\"', worst_group)
      
      results[[length(results) + 1]] <- list(
        name = paste0("Conditional missingness: ", tgt, " depends on ", pred),
        desc = switch(lang,
                      de = paste0("Fehlende Werte in '", tgt, "' h\u00e4ngen signifikant von '", pred, "' ab (Cram\u00e9r's V=", round(cramers_v, 2), ", p<0.001). H\u00f6chste Missingness (", round(100*worst_rate, 1), "%) wenn '", pred, "'='", worst_group, "'. Dies deutet auf MAR hin."),
                      fr = paste0("Les valeurs manquantes dans '", tgt, "' d\u00e9pendent significativement de '", pred, "' (V de Cram\u00e9r=", round(cramers_v, 2), ", p<0.001). Missingness maximale (", round(100*worst_rate, 1), "%) quand '", pred, "'='", worst_group, "'. Cela sugg\u00e8re un m\u00e9canisme MAR."),
                      paste0("Missing values in '", tgt, "' are significantly associated with '", pred, "' (Cram\u00e9r's V=", round(cramers_v, 2), ", p<0.001). Highest missingness (", round(100*worst_rate, 1), "%) when '", pred, "'='", worst_group, "'. This indicates a MAR (Missing At Random) mechanism — standard complete-case analysis will be biased.")),
        reason = paste0("Chi-squared p<0.001, Cram\u00e9r's V=", round(cramers_v, 2), ". Group '", worst_group, "' has ", round(100*worst_rate, 1), "% missing vs overall ", round(100*mean(tgt_missing), 1), "%."),
        sev = if (cramers_v > 0.50) "High" else "Medium",
        expr = paste0("(is.na(", sym_tgt, ") | trimws(as.character(", sym_tgt, "))==\"\") & as.character(", sym_pred, ")==\"", worst_safe, "\""),
        col = paste0(tgt, " | ", pred),
        op = "COND_MISSING", val = paste0("V=", round(cramers_v, 2)),
        cross = TRUE
      )
    }
  }
  results
}

# ── Multi-Column Duplicate Fingerprints ─────────────────────────────────────
# Detects rows that are near-identical across multiple columns simultaneously.
# Uses a composite hash approach — performant even for large datasets.
ai_cross_duplicates <- function(df, cols, lang = "en", sample_n = 50000) {
  results <- list()
  if (length(cols) < 2 || nrow(df) < 10) return(results)
  
  # Select meaningful columns for fingerprinting (exclude pure IDs)
  fp_cols <- cols[vapply(cols, function(cn) {
    x <- df[[cn]]
    n_unique <- length(unique(x[!is.na(x)]))
    # Column should have some but not all unique values
    n_unique > 1 && n_unique < nrow(df) * 0.95
  }, logical(1))]
  
  if (length(fp_cols) < 2) return(results)
  if (length(fp_cols) > 8) fp_cols <- fp_cols[1:8]
  
  # Build composite fingerprint from multiple column subsets
  # Use 3-column and 4-column windows for richer pattern detection
  n <- nrow(df)
  idx <- if (n > sample_n) sort(sample.int(n, sample_n)) else seq_len(n)
  sdf <- df[idx, fp_cols, drop = FALSE]
  
  # Full fingerprint across all selected columns
  fp <- apply(sdf, 1, function(row) paste(trimws(as.character(row)), collapse = "||"))
  fp_tab <- table(fp)
  dup_fps <- names(fp_tab[fp_tab > 1])
  
  if (length(dup_fps) == 0) return(results)
  
  n_dup_records <- sum(fp_tab[dup_fps])
  dup_rate <- n_dup_records / length(fp)
  
  if (dup_rate < 0.005) return(results)  # less than 0.5% — not worth flagging
  
  # Find which rows are duplicates (in sampled data, map back to original indices)
  dup_mask <- fp %in% dup_fps
  dup_rows <- idx[dup_mask]
  
  # Build expression: paste columns to create a composite key and check for dup
  col_paste <- paste(vapply(fp_cols, function(cn) {
    paste0("as.character(", safe_sym(cn), ")")
  }, character(1)), collapse = ", '||', ")
  expr <- paste0("(duplicated(paste0(", col_paste, ")) | duplicated(paste0(", col_paste, "), fromLast=TRUE))")
  
  sev <- if (dup_rate > 0.05) "High" else if (dup_rate > 0.01) "Medium" else "Low"
  
  results[[1]] <- list(
    name = paste0("Multi-column duplicates across [", paste(fp_cols, collapse=", "), "]"),
    desc = switch(lang,
                  de = paste0(round(100*dup_rate, 1), "% der Datens\u00e4tze sind \u00fcber ", length(fp_cols), " Spalten identisch. M\u00f6gliche Datenverdopplung oder Import-Artefakt."),
                  fr = paste0(round(100*dup_rate, 1), "% des enregistrements sont identiques sur ", length(fp_cols), " colonnes. Duplication possible ou artefact d'importation."),
                  paste0(round(100*dup_rate, 1), "% of records are identical across ", length(fp_cols), " columns [", paste(fp_cols, collapse=", "), "]. Possible data duplication or import artifact.")),
    reason = paste0(n_dup_records, " records (", round(100*dup_rate, 1), "%) share identical composite fingerprints across ", length(fp_cols), " columns. This often indicates accidental row duplication, merge artifacts, or test data contamination."),
    sev = sev,
    expr = expr,
    col = paste(fp_cols, collapse = " + "),
    op = "COMPOSITE_DUP", val = paste0(round(100*dup_rate, 1), "%"),
    cross = TRUE
  )
  results
}

# ── Benford's Law Deviation (Data Fabrication Indicator) ─────────────────────
# Natural numeric data follows Benford's Law for leading digits.
# Significant deviation can indicate fabricated or synthetic data.
ai_benfords_law <- function(df, num_cols, lang = "en") {
  results <- list()
  benford_expected <- log10(1 + 1/(1:9))  # theoretical Benford distribution
  
  for (cn in num_cols) {
    vals <- suppressWarnings(as.numeric(df[[cn]]))
    vals <- abs(vals[is.finite(vals) & vals != 0])
    if (length(vals) < 100) next  # Benford only meaningful with sufficient n
    
    # Extract leading digit
    leading <- as.integer(substr(format(vals, scientific = FALSE, trim = TRUE), 1, 1))
    leading <- leading[leading >= 1 & leading <= 9]
    if (length(leading) < 50) next
    
    observed <- tabulate(leading, nbins = 9) / length(leading)
    if (length(observed) != 9 || any(is.na(observed))) next
    
    # Chi-squared goodness of fit
    chi <- tryCatch({
      chisq.test(tabulate(leading, nbins = 9), p = benford_expected, rescale.p = TRUE)
    }, error = function(e) NULL)
    
    if (is.null(chi) || chi$p.value >= 0.001) next
    
    # Only flag if the deviation is large (avoid noise)
    max_dev <- max(abs(observed - benford_expected))
    if (max_dev < 0.08) next  # at least 8 percentage points deviation
    
    sym <- safe_sym(cn)
    results[[length(results) + 1]] <- list(
      name = paste0("Benford's Law deviation: ", cn),
      desc = switch(lang,
                    de = paste0("Die Verteilung der Anfangsziffern in '", cn, "' weicht signifikant von Benfords Gesetz ab (p<0.001, max. Abweichung ", round(100*max_dev, 1), "%). Dies kann auf synthetische oder fabrizierte Daten hindeuten."),
                    fr = paste0("La distribution des premiers chiffres dans '", cn, "' d\u00e9vie significativement de la loi de Benford (p<0.001, d\u00e9viation max ", round(100*max_dev, 1), "%). Cela peut indiquer des donn\u00e9es synth\u00e9tiques ou fabriqu\u00e9es."),
                    paste0("Leading-digit distribution in '", cn, "' deviates significantly from Benford's Law (p<0.001, max deviation ", round(100*max_dev, 1), "%). This may indicate synthetic, fabricated, or heavily rounded data.")),
      reason = paste0("Chi-squared p<0.001. Max digit-frequency deviation: ", round(100*max_dev, 1), "%. n=", length(leading), " non-zero values. Benford's Law applies to naturally occurring numeric data — deviation suggests non-natural data generation."),
      sev = if (max_dev > 0.15) "High" else "Medium",
      expr = "FALSE",  # informational — cannot be expressed as row-level flag
      col = cn,
      op = "BENFORD", val = paste0("dev=", round(100*max_dev, 1), "%"),
      cross = FALSE
    )
  }
  results
}

# ── Entropy Anomalies ────────────────────────────────────────────────────────
# Detects columns with suspiciously low entropy (near-constant) or
# suspiciously high entropy (random noise) relative to expectation.
ai_entropy_anomalies <- function(df, cols, lang = "en") {
  results <- list()
  n <- nrow(df)
  if (n < 20) return(results)
  
  for (cn in cols) {
    x <- as.character(df[[cn]])
    x <- x[!is.na(x) & nzchar(trimws(x))]
    if (length(x) < 10) next
    
    tab <- table(x)
    n_levels <- length(tab)
    
    # Skip high-cardinality columns (IDs, free text)
    if (n_levels > min(500, length(x) * 0.8)) next
    if (n_levels < 2) {
      sym <- safe_sym(cn)
      results[[length(results) + 1]] <- list(
        name = paste0("Constant column: ", cn),
        desc = switch(lang,
                      de = paste0("Spalte '", cn, "' enth\u00e4lt nur einen einzigen Wert ('", names(tab)[1], "'). Informationsgehalt ist null."),
                      fr = paste0("La colonne '", cn, "' ne contient qu'une seule valeur ('", names(tab)[1], "'). Contenu informatif nul."),
                      paste0("Column '", cn, "' contains only a single value ('", names(tab)[1], "'). Zero information content — may be a placeholder or import artifact.")),
        reason = paste0("Entropy = 0. Single value: '", names(tab)[1], "' (n=", length(x), "). Constant columns waste storage and can cause division-by-zero in statistical models."),
        sev = "Low",
        expr = "FALSE",
        col = cn, op = "ZERO_ENTROPY", val = names(tab)[1],
        cross = FALSE
      )
      next
    }
    
    # Compute Shannon entropy
    p <- as.numeric(tab) / sum(tab)
    entropy <- -sum(p * log2(p))
    max_entropy <- log2(n_levels)
    norm_entropy <- if (max_entropy > 0) entropy / max_entropy else 0
    
    # Near-uniform distribution in categorical (> 5 levels) — suspicious
    if (n_levels >= 5 && n_levels <= 100 && norm_entropy > 0.98 && length(x) > 50) {
      results[[length(results) + 1]] <- list(
        name = paste0("Suspiciously uniform distribution: ", cn),
        desc = switch(lang,
                      de = paste0("'", cn, "' hat eine nahezu perfekt gleichm\u00e4\u00dfige Verteilung (normalisierte Entropie=", round(norm_entropy, 3), "). Dies ist bei nat\u00fcrlichen klinischen Daten ungew\u00f6hnlich."),
                      fr = paste0("'", cn, "' a une distribution presque parfaitement uniforme (entropie normalis\u00e9e=", round(norm_entropy, 3), "). Ceci est inhabituel pour des donn\u00e9es cliniques naturelles."),
                      paste0("'", cn, "' has a nearly perfect uniform distribution (normalized entropy=", round(norm_entropy, 3), "). Natural clinical data rarely shows perfect uniformity — may indicate synthetic or randomized test data.")),
        reason = paste0("Normalized Shannon entropy = ", round(norm_entropy, 3), " across ", n_levels, " levels. Natural data typically shows skewed distributions."),
        sev = "Low",
        expr = "FALSE",
        col = cn, op = "UNIFORM_DIST", val = paste0("H=", round(norm_entropy, 3)),
        cross = FALSE
      )
    }
    
    # Extremely low entropy (< 0.10) with multiple levels — near-degenerate
    if (n_levels >= 3 && norm_entropy < 0.10) {
      dominant <- names(sort(tab, decreasing = TRUE))[1]
      dom_pct <- round(100 * max(tab) / sum(tab), 1)
      results[[length(results) + 1]] <- list(
        name = paste0("Degenerate distribution: ", cn),
        desc = switch(lang,
                      de = paste0("'", cn, "' hat ", n_levels, " Levels, aber '", dominant, "' dominiert mit ", dom_pct, "%. Effektiv informationsarm trotz mehrerer Kategorien."),
                      fr = paste0("'", cn, "' a ", n_levels, " niveaux, mais '", dominant, "' domine \u00e0 ", dom_pct, "%. Effectivement pauvre en information malgr\u00e9 plusieurs cat\u00e9gories."),
                      paste0("'", cn, "' has ", n_levels, " levels, but '", dominant, "' dominates at ", dom_pct, "%. Effectively information-poor despite multiple categories — may need recoding or review.")),
        reason = paste0("Normalized entropy = ", round(norm_entropy, 3), ". Dominant value '", dominant, "' at ", dom_pct, "%."),
        sev = "Low",
        expr = "FALSE",
        col = cn, op = "LOW_ENTROPY", val = paste0(dom_pct, "% dominant"),
        cross = FALSE
      )
    }
  }
  results
}

# ── Cross-Column Date Ordering Violations ────────────────────────────────────
# Generic detection of any date column pairs where chronological order is violated.
# Goes beyond the hardcoded admission/discharge check by testing ALL date pairs.
ai_cross_date_order <- function(df, date_cols, lang = "en") {
  results <- list()
  if (length(date_cols) < 2) return(results)
  
  # Convert all to Date
  date_data <- lapply(date_cols, function(cn) {
    x <- df[[cn]]
    if (inherits(x, "Date")) return(x)
    if (inherits(x, "POSIXt")) return(as.Date(x))
    suppressWarnings(as.Date(as.character(x)))
  })
  names(date_data) <- date_cols
  
  # For each pair, estimate chronological order from median and check violations
  for (i in seq_along(date_cols)[-length(date_cols)]) {
    for (j in (i + 1):length(date_cols)) {
      cn_a <- date_cols[i]; cn_b <- date_cols[j]
      a <- date_data[[cn_a]]; b <- date_data[[cn_b]]
      ok <- !is.na(a) & !is.na(b)
      if (sum(ok) < 20) next
      
      # Determine expected order from majority
      diff_days <- as.numeric(b[ok] - a[ok])
      pct_positive <- mean(diff_days >= 0)
      pct_negative <- mean(diff_days < 0)
      
      # If one direction dominates (>85%) but some violate, flag the violators
      if (pct_positive > 0.85 && pct_negative > 0.01) {
        n_violations <- sum(diff_days < 0)
        sym_a <- safe_sym(cn_a); sym_b <- safe_sym(cn_b)
        expr <- paste0("!is.na(", sym_a, ") & !is.na(", sym_b, ") & as.Date(", sym_b, ") < as.Date(", sym_a, ")")
        results[[length(results) + 1]] <- list(
          name = paste0("Date order violation: ", cn_b, " before ", cn_a),
          desc = switch(lang,
                        de = paste0(n_violations, " Datens\u00e4tze wo '", cn_b, "' vor '", cn_a, "' liegt (", round(100*pct_negative, 1), "%). In ", round(100*pct_positive, 1), "% ist die umgekehrte Reihenfolge korrekt."),
                        fr = paste0(n_violations, " enregistrements o\u00f9 '", cn_b, "' pr\u00e9c\u00e8de '", cn_a, "' (", round(100*pct_negative, 1), "%). ", round(100*pct_positive, 1), "% suivent l'ordre attendu."),
                        paste0(n_violations, " records where '", cn_b, "' is before '", cn_a, "' (", round(100*pct_negative, 1), "%). ", round(100*pct_positive, 1), "% follow the expected chronological order.")),
          reason = paste0("Expected order: ", cn_a, " \u2264 ", cn_b, " (based on ", round(100*pct_positive, 1), "% majority). ", n_violations, " violations detected."),
          sev = if (pct_negative > 0.05) "High" else "Medium",
          expr = expr,
          col = paste0(cn_a, " \u2192 ", cn_b),
          op = "DATE_ORDER", val = paste0(n_violations, " violations"),
          cross = TRUE
        )
      } else if (pct_negative > 0.85 && pct_positive > 0.01) {
        n_violations <- sum(diff_days >= 0)
        sym_a <- safe_sym(cn_a); sym_b <- safe_sym(cn_b)
        expr <- paste0("!is.na(", sym_a, ") & !is.na(", sym_b, ") & as.Date(", sym_a, ") < as.Date(", sym_b, ")")
        results[[length(results) + 1]] <- list(
          name = paste0("Date order violation: ", cn_a, " before ", cn_b),
          desc = switch(lang,
                        de = paste0(n_violations, " Datens\u00e4tze wo '", cn_a, "' vor '", cn_b, "' liegt, obwohl die Mehrheit umgekehrt ist."),
                        fr = paste0(n_violations, " enregistrements o\u00f9 '", cn_a, "' pr\u00e9c\u00e8de '", cn_b, "', bien que la majorit\u00e9 soit invers\u00e9e."),
                        paste0(n_violations, " records where '", cn_a, "' is before '", cn_b, "', though the majority have the reverse order.")),
          reason = paste0("Expected order: ", cn_b, " \u2264 ", cn_a, ". ", n_violations, " violations."),
          sev = if (pct_positive > 0.05) "High" else "Medium",
          expr = expr,
          col = paste0(cn_b, " \u2192 ", cn_a),
          op = "DATE_ORDER", val = paste0(n_violations, " violations"),
          cross = TRUE
        )
      }
    }
  }
  results
}

# ── Format Consistency Across Related Columns ────────────────────────────────
# Detects when columns that should share a format (e.g., multiple date fields,
# multiple code fields) have inconsistent formatting patterns.
ai_cross_format_consistency <- function(df, cols, lang = "en") {
  results <- list()
  if (length(cols) < 2) return(results)
  
  # Group columns by likely type based on name patterns
  date_pattern <- "date|datum|zeit|time|dt_|_dt$"
  code_pattern <- "icd|ops|code|diag|proc"
  id_pattern   <- "id$|_id|nummer|number|nr$|_nr"
  
  groups <- list()
  for (cn in cols) {
    cn_low <- tolower(cn)
    if (grepl(date_pattern, cn_low)) groups$date <- c(groups$date, cn)
    else if (grepl(code_pattern, cn_low)) groups$code <- c(groups$code, cn)
    else if (grepl(id_pattern, cn_low)) groups$id <- c(groups$id, cn)
  }
  
  for (grp_name in names(groups)) {
    grp_cols <- groups[[grp_name]]
    if (length(grp_cols) < 2) next
    
    # Detect format by sampling first 200 non-NA values per column
    formats <- list()
    for (cn in grp_cols) {
      vals <- as.character(df[[cn]])
      vals <- vals[!is.na(vals) & nzchar(trimws(vals))]
      if (length(vals) > 200) vals <- vals[1:200]
      if (length(vals) == 0) next
      
      # Detect dominant format pattern
      fmt <- if (grp_name == "date") {
        patterns <- c(
          "YYYY-MM-DD" = "^\\d{4}-\\d{2}-\\d{2}$",
          "DD.MM.YYYY" = "^\\d{2}\\.\\d{2}\\.\\d{4}$",
          "DD/MM/YYYY" = "^\\d{2}/\\d{2}/\\d{4}$",
          "MM/DD/YYYY" = "^\\d{2}/\\d{2}/\\d{4}$",
          "YYYY-MM-DD HH:MM:SS" = "^\\d{4}-\\d{2}-\\d{2}[T ]\\d{2}:\\d{2}",
          "other" = "."
        )
        det <- vapply(patterns, function(p) mean(grepl(p, vals)), numeric(1))
        names(which.max(det))
      } else {
        # For codes/IDs: detect predominant character class pattern
        if (mean(grepl("^[A-Z]\\d", vals)) > 0.5) "ALPHA-NUM"
        else if (mean(grepl("^\\d+-", vals)) > 0.5) "NUM-DASH"
        else if (mean(grepl("^\\d+$", vals)) > 0.5) "PURE-NUM"
        else "MIXED"
      }
      formats[[cn]] <- fmt
    }
    
    if (length(formats) < 2) next
    
    unique_fmts <- unique(unlist(formats))
    if (length(unique_fmts) > 1) {
      fmt_summary <- paste(vapply(names(formats), function(cn) {
        paste0(cn, "=", formats[[cn]])
      }, character(1)), collapse = ", ")
      
      results[[length(results) + 1]] <- list(
        name = paste0("Format inconsistency in ", grp_name, " columns"),
        desc = switch(lang,
                      de = paste0("Spalten der gleichen Gruppe (", grp_name, ") verwenden unterschiedliche Formate: ", fmt_summary, ". Dies kann Joins, Vergleiche und automatische Typenerkennung beeintr\u00e4chtigen."),
                      fr = paste0("Les colonnes du m\u00eame groupe (", grp_name, ") utilisent des formats diff\u00e9rents: ", fmt_summary, ". Cela peut affecter les jointures et comparaisons."),
                      paste0("Columns of the same group (", grp_name, ") use different formats: ", fmt_summary, ". This can break joins, comparisons, and automatic type inference.")),
        reason = paste0("Detected ", length(unique_fmts), " different formats across ", length(formats), " related columns. Format standardization is recommended before analysis."),
        sev = "Medium",
        expr = "FALSE",
        col = paste(names(formats), collapse = " + "),
        op = "FORMAT_MISMATCH", val = fmt_summary,
        cross = TRUE
      )
    }
  }
  results
}

# ═══════════════════════════════════════════════════════════════════════════════
# MASTER FUNCTION: ai_suggest_checks_v2
# Generates highly targeted, domain-aware custom check suggestions.
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# MASTER FUNCTION: ai_suggest_checks ( Advanced Cross-Column Intelligence)
# Generates highly targeted, domain-aware custom check suggestions.
# additions:
#   - Cross-column correlation detection (Spearman)
#   - Conditional missing patterns (MAR detection via Chi-squared + Cramér's V)
#   - Multi-column duplicate fingerprinting
#   - Benford's Law deviation (data fabrication indicator)
#   - Entropy anomalies (constant / suspiciously uniform columns)
#   - Generic date-ordering violations across ALL date pairs
#   - Format consistency across related column groups
# ═══════════════════════════════════════════════════════════════════════════════

ai_suggest_checks <- function(df, lang = "en", max_checks = 25, sample_n = 50000, seed = 1) {
  if (is.null(df) || nrow(df) == 0) return(list())
  n <- nrow(df)
  
  cols <- names(df)
  if (length(cols) == 0) return(list())
  
  idx <- sample_idx(n, sample_n = sample_n, seed = seed)
  sdf <- df[idx, cols, drop = FALSE]
  
  sugg <- list()
  add <- function(name, desc, reason, sev, expr, col = "", op = "", val = "", cross = FALSE) {
    sugg[[length(sugg) + 1]] <<- list(
      name = name, desc = desc, reason = reason, sev = sev,
      col = col, op = op, val = val, expression_raw = expr,
      cross_column = cross
    )
  }
  
  # ═══════════════════════════════════════════════════════════════════════════
  # PHASE 1: Per-Column Analysis (unchanged from V0.1)
  # ═══════════════════════════════════════════════════════════════════════════
  for (cn in cols) {
    x <- sdf[[cn]]
    sym <- safe_sym(cn)
    
    # Missing / blank
    miss <- mean(is_blank(x))
    if (is.finite(miss) && miss > 0) {
      sev <- if (miss >= 0.20) "High" else if (miss >= 0.05) "Medium" else "Low"
      expr <- paste0("is.na(", sym, ") | trimws(as.character(", sym, "))==\"\"")
      add(
        name = paste0("Completeness: Missing values in ", cn),
        desc = paste0("Detect records where '", cn, "' is missing/blank."),
        reason = paste0("Missingness ~", round(100 * miss, 1), "% in a representative sample."),
        sev = sev,
        expr = expr,
        col = cn, op = "IS NA/BLANK", val = ""
      )
    }
    
    # Whitespace / formatting anomalies
    if (is.character(x) || is.factor(x)) {
      xc <- as.character(x)
      ws <- mean(grepl("^\\s|\\s$|\\s{2,}", xc %||% ""))
      if (is.finite(ws) && ws > 0.02) {
        expr <- paste0("grepl(\"^\\\\s|\\\\s$|\\\\s{2,}\", as.character(", sym, "))")
        add(
          name = paste0("Formatting: Hidden whitespace in ", cn),
          desc = paste0("Flags leading/trailing or double spaces in '", cn, "'."),
          reason = "Hidden whitespace often creates false categories and breaks joins/mappings.",
          sev = if (ws > 0.10) "Medium" else "Low",
          expr = expr,
          col = cn, op = "HAS WHITESPACE", val = ""
        )
      }
      
      # Near-duplicate levels (typos)
      if (length(unique(trimws(tolower(xc[nzchar(xc)])))) >= 15) {
        hint <- ai_typos_hint(xc)
        if (nzchar(hint)) {
          expr <- paste0("FALSE")
          add(
            name = paste0("Coding consistency: Possible typos in ", cn),
            desc = paste0(" analysis found near-duplicate categories in '", cn, "'."),
            reason = hint,
            sev = "Low",
            expr = expr,
            col = cn, op = "INFO", val = ""
          )
        }
      }
    }
    
    # Numeric outliers (robust)
    xnum <- NULL
    if (is.numeric(x) || is.integer(x)) xnum <- suppressWarnings(as.numeric(x))
    if (is.null(xnum) && (is.character(x) || is.factor(x))) xnum <- as_num_lenient(x)
    
    if (!is.null(xnum)) {
      ok <- is.finite(xnum)
      if (sum(ok) >= 30) {
        med <- median(xnum[ok], na.rm = TRUE)
        md <- mad(xnum[ok], constant = 1, na.rm = TRUE)
        if (is.finite(md) && md > 0) {
          z <- abs((xnum - med) / md)
          out_rate <- mean(z[ok] > 8)
          if (is.finite(out_rate) && out_rate > 0.001) {
            sev <- if (out_rate >= 0.02) "High" else if (out_rate >= 0.005) "Medium" else "Low"
            expr <- paste0("({.x<-as_num_lenient(", sym, "); .m<-median(.x,na.rm=TRUE); .d<-mad(.x,constant=1,na.rm=TRUE); !is.na(.x)&.d>0&abs((.x-.m)/.d)>8})")
            add(
              name = paste0("Outliers: Robust numeric extremes in ", cn),
              desc = paste0("Flags robust outliers in '", cn, "' using MAD z-score (>8)."),
              reason = paste0("Outlier rate ~", round(100 * out_rate, 2), "% in sample. These often indicate unit mix-ups, parsing, or data entry errors."),
              sev = sev,
              expr = expr,
              col = cn, op = "ROBUST OUTLIER", val = "MAD z > 8"
            )
          }
        }
      }
    }
  }
  
  # ═══════════════════════════════════════════════════════════════════════════
  # PHASE 2: Cross-Column Clinical Logic (V0.1 — preserved)
  # ═══════════════════════════════════════════════════════════════════════════
  cn_low <- tolower(cols)
  pick <- function(pattern) {
    i <- match(TRUE, grepl(pattern, cn_low))
    if (is.na(i)) NA_character_ else cols[i]
  }
  
  col_adm <- pick("admission|aufnahme|visit_start|start_date|encounter_start")
  col_dis <- pick("discharge|entlass|visit_end|end_date|encounter_end")
  col_dob <- pick("birth|geburt|dob|date_of_birth")
  col_age <- pick("^age$|alter")
  
  if (!is.na(col_adm) && !is.na(col_dis)) {
    a <- safe_sym(col_adm); d <- safe_sym(col_dis)
    expr <- paste0("!is.na(", d, ") & !is.na(", a, ") & as.Date(", d, ") < as.Date(", a, ")")
    add(
      name = "Temporal consistency: Discharge before admission",
      desc = paste0("Flags records where '", col_dis, "' is earlier than '", col_adm, "'."),
      reason = "This can silently invalidate LOS, readmission logic, and cohort windows.",
      sev = "Critical",
      expr = expr,
      col = paste0(col_dis, " vs ", col_adm), op = "<", val = "", cross = TRUE
    )
  }
  
  if (!is.na(col_dob) && !is.na(col_adm)) {
    b <- safe_sym(col_dob); a <- safe_sym(col_adm)
    expr <- paste0("!is.na(", a, ") & !is.na(", b, ") & as.Date(", a, ") < as.Date(", b, ")")
    add(
      name = "Temporal consistency: Encounter before birth date",
      desc = paste0("Flags records where '", col_adm, "' is earlier than '", col_dob, "'."),
      reason = "Often caused by swapped columns, wrong date format (DD/MM vs MM/DD), or placeholder dates.",
      sev = "Critical",
      expr = expr,
      col = paste0(col_adm, " vs ", col_dob), op = "<", val = "", cross = TRUE
    )
  }
  
  if (!is.na(col_age) && !is.na(col_dob) && !is.na(col_adm)) {
    ag <- safe_sym(col_age); b <- safe_sym(col_dob); a <- safe_sym(col_adm)
    expr <- paste0("({.a<-as_num_lenient(", ag, "); .y<-floor(as.numeric(as.Date(", a, ")-as.Date(", b, "))/365.25); !is.na(.a)&is.finite(.y)&abs(.a-.y)>2})")
    add(
      name = "Identity consistency: Age mismatches DOB + admission",
      desc = paste0("Flags age inconsistencies (>2y) between '", col_age, "' and derived age from DOB/admission."),
      reason = "These inconsistencies are easy to miss but strongly distort age-stratified outcomes and scores.",
      sev = "High",
      expr = expr,
      col = paste0(col_age, " vs DOB/Admission"), op = "MISMATCH", val = ">2y", cross = TRUE
    )
  }
  
  col_icd <- pick("^icd$|diagnos|diagnosis|icd10|icd_")
  if (!is.na(col_icd)) {
    ic <- safe_sym(col_icd)
    expr <- paste0("({.s<-toupper(as.character(", ic, ")); !is.na(.s) & (grepl(\"(^|;|,|\\\\s)R99($|;|,|\\\\s)\", .s, perl=TRUE) | grepl(\"(^|;|,|\\\\s)Z00(\\\\.[0-9A-Z]{1,4})?($|;|,|\\\\s)\", .s, perl=TRUE) | grepl(\"\\\\.(9|90|99)($|;|,|\\\\s)\", .s, perl=TRUE))})")
    add(
      name = "Code integrity: Unspecific ICD usage (R99, Z00.*, *.9/*.90/*.99)",
      desc = paste0("Flags potentially unspecific ICD codes inside '", col_icd, "'."),
      reason = "Technically valid codes can still be conceptually imprecise and reduce comorbidity score discriminative power.",
      sev = "High",
      expr = expr,
      col = col_icd, op = "REGEX", val = "R99/Z00/*.(9|90|99)"
    )
  }
  
  # ═══════════════════════════════════════════════════════════════════════════
  # PHASE 3: V2.2 Advanced Cross-Column Intelligence
  # ═══════════════════════════════════════════════════════════════════════════
  
  # Classify columns for targeted analysis
  num_cols <- cols[vapply(sdf, function(x) {
    if (is.numeric(x) || is.integer(x)) return(TRUE)
    xn <- as_num_lenient(x)
    sum(is.finite(xn)) > nrow(sdf) * 0.5
  }, logical(1))]
  
  date_cols <- cols[vapply(sdf, function(x) {
    if (inherits(x, "Date") || inherits(x, "POSIXt")) return(TRUE)
    xc <- as.character(x)
    xc <- xc[!is.na(xc) & nzchar(trimws(xc))]
    if (length(xc) < 10) return(FALSE)
    mean(grepl("^\\d{4}-\\d{2}-\\d{2}", xc) | grepl("^\\d{2}[./]\\d{2}[./]\\d{4}", xc)) > 0.5
  }, logical(1))]
  
  # 3a. Cross-column correlation anomalies
  tryCatch({
    corr_results <- ai_cross_correlation(sdf, num_cols, lang)
    for (r in corr_results) add(r$name, r$desc, r$reason, r$sev, r$expr, r$col, r$op, r$val, r$cross)
  }, error = function(e) NULL)
  
  # 3b. Conditional missing patterns (MAR detection)
  tryCatch({
    mar_results <- ai_cross_missing_pattern(sdf, cols, lang)
    for (r in mar_results) add(r$name, r$desc, r$reason, r$sev, r$expr, r$col, r$op, r$val, r$cross)
  }, error = function(e) NULL)
  
  # 3c. Multi-column duplicate fingerprints
  tryCatch({
    dup_results <- ai_cross_duplicates(sdf, cols, lang, sample_n)
    for (r in dup_results) add(r$name, r$desc, r$reason, r$sev, r$expr, r$col, r$op, r$val, r$cross)
  }, error = function(e) NULL)
  
  # 3d. Benford's Law deviation
  tryCatch({
    benford_results <- ai_benfords_law(sdf, num_cols, lang)
    for (r in benford_results) add(r$name, r$desc, r$reason, r$sev, r$expr, r$col, r$op, r$val, r$cross)
  }, error = function(e) NULL)
  
  # 3e. Entropy anomalies
  tryCatch({
    entropy_results <- ai_entropy_anomalies(sdf, cols, lang)
    for (r in entropy_results) add(r$name, r$desc, r$reason, r$sev, r$expr, r$col, r$op, r$val, r$cross)
  }, error = function(e) NULL)
  
  # 3f. Generic cross-column date ordering violations
  tryCatch({
    date_order_results <- ai_cross_date_order(sdf, date_cols, lang)
    for (r in date_order_results) add(r$name, r$desc, r$reason, r$sev, r$expr, r$col, r$op, r$val, r$cross)
  }, error = function(e) NULL)
  
  # 3g. Format consistency across related column groups
  tryCatch({
    fmt_results <- ai_cross_format_consistency(sdf, cols, lang)
    for (r in fmt_results) add(r$name, r$desc, r$reason, r$sev, r$expr, r$col, r$op, r$val, r$cross)
  }, error = function(e) NULL)
  
  # ═══════════════════════════════════════════════════════════════════════════
  # RANKING: Prioritize by severity, then limit to max_checks
  # ═══════════════════════════════════════════════════════════════════════════
  sev_priority <- c(Critical = 1, High = 2, Medium = 3, Low = 4)
  ord <- order(vapply(sugg, function(s) sev_priority[s$sev] %||% 9, numeric(1)))
  sugg <- sugg[ord]
  if (length(sugg) > max_checks) sugg <- sugg[seq_len(max_checks)]
  sugg
}

# ── Section 6: Check Metadata (77 built-in, per specification) ───────────────
# Each check has: id, category, short description, what it flags, required columns,
# severity, and a brief implementation note.

CL <- list(
  cat1_1  = list(w = "Admission present but ICD missing/empty.",               n = c("admission_date","icd"),       sev = "High"),
  cat1_2  = list(w = "Surgery mention in notes; OPS missing (>10%).",          n = c("anamnese","ops"),              sev = "Medium"),
  cat1_3  = list(w = "Diabetes mention; no E10-E14 ICD.",                      n = c("anamnese","icd"),              sev = "High"),
  cat1_4  = list(w = "Heart disease mention; no I-chapter ICD.",               n = c("anamnese","icd"),              sev = "Medium"),
  cat1_5  = list(w = "Chemotherapy mention; OPS missing.",                     n = c("anamnese","ops"),              sev = "High"),
  cat1_6  = list(w = "COPD mention; no J44 ICD.",                             n = c("anamnese","icd"),              sev = "High"),
  cat1_7  = list(w = "Radiology mention; OPS missing.",                       n = c("anamnese","ops"),              sev = "Medium"),
  cat1_8  = list(w = "Allergy mention; no T78 ICD.",                          n = c("anamnese","icd"),              sev = "Medium"),
  cat1_9  = list(w = "Dialysis mention; OPS missing.",                        n = c("anamnese","ops"),              sev = "Medium"),
  cat1_10 = list(w = "Hypertension mention; no I10 ICD.",                     n = c("anamnese","icd"),              sev = "Medium"),
  cat1_11 = list(w = "Endoscopy mention; OPS missing.",                       n = c("anamnese","ops"),              sev = "Medium"),
  cat1_12 = list(w = "Stroke mention; no I63/I64 ICD.",                       n = c("anamnese","icd"),              sev = "High"),
  cat1_13 = list(w = "Infection mention; no B-chapter ICD.",                   n = c("anamnese","icd"),              sev = "Medium"),
  cat1_14 = list(w = "Prosthesis mention; OPS missing.",                      n = c("anamnese","ops"),              sev = "Medium"),
  cat1_15 = list(w = "Depression mention; no F32-F33 ICD.",                    n = c("anamnese","icd"),              sev = "Medium"),
  cat1_16 = list(w = "Admission present but both ICD and OPS missing.",        n = c("admission_date","icd","ops"),  sev = "High"),
  cat2_1  = list(w = "Prostate cancer (C61) in age < 15.",                    n = c("age","icd"),                   sev = "High"),
  cat2_2  = list(w = "Alzheimer (F00/G30) in age < 30.",                      n = c("age","icd"),                   sev = "High"),
  cat2_3  = list(w = "Child dev. disorder (F80-F89) in age > 70.",            n = c("age","icd"),                   sev = "Medium"),
  cat2_4  = list(w = "Osteoporosis (M80/M81) in age < 18.",                   n = c("age","icd"),                   sev = "Medium"),
  cat2_5  = list(w = "Measles (B05) in age > 60.",                            n = c("age","icd"),                   sev = "Medium"),
  cat2_6  = list(w = "Birth ICD (O60-O75) in male patient.",                  n = c("gender","icd"),                sev = "High"),
  cat2_7  = list(w = "Menopause (N95) in male patient.",                      n = c("gender","icd"),                sev = "High"),
  cat2_8  = list(w = "Teen acne (L70) in neonate (age < 1).",                 n = c("age","icd"),                   sev = "Medium"),
  cat2_9  = list(w = "Macular degeneration (H35.3) in age < 30.",             n = c("age","icd"),                   sev = "Medium"),
  cat2_10 = list(w = "Infantile CP (G80) in adult (age > 21).",               n = c("age","icd"),                   sev = "Medium"),
  cat2_11 = list(w = "Preeclampsia (O14) in male patient.",                   n = c("gender","icd"),                sev = "High"),
  cat2_12 = list(w = "Juvenile arthritis (M08) in age > 70.",                 n = c("age","icd"),                   sev = "Medium"),
  cat2_13 = list(w = "Testosterone deficiency (E29) in female patient.",       n = c("gender","icd"),                sev = "Medium"),
  cat2_14 = list(w = "Testicular tumor (C62) in female patient.",             n = c("gender","icd"),                sev = "High"),
  cat2_15 = list(w = "Delayed puberty (E30.0) in age > 60.",                  n = c("age","icd"),                   sev = "Medium"),
  cat3_1  = list(w = "Ovarian cyst (N83) in male patient.",                   n = c("gender","icd"),                sev = "High"),
  cat3_2  = list(w = "Prostatitis (N41) in female patient.",                  n = c("gender","icd"),                sev = "High"),
  cat3_3  = list(w = "Pregnancy (O-codes) in male patient.",                  n = c("gender","icd"),                sev = "High"),
  cat3_4  = list(w = "Testicular cancer (C62) in female patient.",            n = c("gender","icd"),                sev = "High"),
  cat3_5  = list(w = "Endometriosis (N80) in male patient.",                  n = c("gender","icd"),                sev = "High"),
  cat3_6  = list(w = "Erectile dysfunction (N52) in female patient.",          n = c("gender","icd"),                sev = "High"),
  cat3_7  = list(w = "Cervical cancer (C53) in male patient.",                n = c("gender","icd"),                sev = "High"),
  cat3_8  = list(w = "Testosterone excess (E28.1) in female patient.",         n = c("gender","icd"),                sev = "Medium"),
  cat3_9  = list(w = "Menstrual disorder (N92/N93) in male patient.",         n = c("gender","icd"),                sev = "High"),
  cat3_10 = list(w = "Breast cancer (C50) in male patient (rare; review).",    n = c("gender","icd"),                sev = "Medium"),
  cat3_11 = list(w = "Phimosis (N47) in female patient.",                     n = c("gender","icd"),                sev = "High"),
  cat3_12 = list(w = "Vulvitis (N76) in male patient.",                       n = c("gender","icd"),                sev = "High"),
  cat3_13 = list(w = "Perinatal codes (P-chapter) in male baby.",             n = c("gender","icd"),                sev = "Medium"),
  cat3_14 = list(w = "Cryptorchidism (Q53) in female patient.",               n = c("gender","icd"),                sev = "High"),
  cat3_15 = list(w = "Hyperemesis gravidarum (O21) in male patient.",         n = c("gender","icd"),                sev = "High"),
  cat4_2  = list(w = "Discharge date before admission date.",                 n = c("admission_date","discharge_date"), sev = "Critical"),
  cat4_4  = list(w = "Duplicate same-day admission per patient.",             n = c("patient_id","admission_date"),     sev = "Medium"),
  cat4_6  = list(w = "Admission date lies in the future.",                    n = c("admission_date"),                  sev = "Medium"),
  cat4_8  = list(w = "Same-day discharge with complex OPS.",                  n = c("admission_date","discharge_date","ops"), sev = "Low"),
  cat4_12 = list(w = "Admission date before birth date.",                     n = c("admission_date","birth_date"),     sev = "Critical"),
  cat4_15 = list(w = "Discharge before admission (dup check).",               n = c("admission_date","discharge_date"), sev = "Critical"),
  cat5_1  = list(w = "Appendectomy OPS without K35 ICD.",                     n = c("ops","icd"),                       sev = "Medium"),
  cat5_2  = list(w = "Knee replacement OPS without M17 ICD.",                 n = c("ops","icd"),                       sev = "Medium"),
  cat5_3  = list(w = "Chemotherapy OPS without cancer ICD.",                  n = c("ops","icd"),                       sev = "High"),
  cat5_4  = list(w = "Heart catheter OPS without I-chapter ICD.",             n = c("ops","icd"),                       sev = "Medium"),
  cat5_5  = list(w = "Dialysis OPS without N18 ICD.",                         n = c("ops","icd"),                       sev = "Medium"),
  cat5_6  = list(w = "C-section OPS in male patient.",                        n = c("ops","gender"),                    sev = "High"),
  cat5_7  = list(w = "Cataract OPS without H25/H26 ICD.",                    n = c("ops","icd"),                       sev = "Medium"),
  cat5_8  = list(w = "Gastric bypass OPS without E66 ICD.",                   n = c("ops","icd"),                       sev = "Medium"),
  cat5_9  = list(w = "Hysterectomy OPS without GYN ICD.",                    n = c("ops","icd"),                       sev = "Medium"),
  cat5_10 = list(w = "Transfusion OPS without anemia ICD.",                   n = c("ops","icd"),                       sev = "Medium"),
  cat5_11 = list(w = "Knee arthroscopy OPS without knee ICD.",                n = c("ops","icd"),                       sev = "Medium"),
  cat5_12 = list(w = "Radiology OPS without ICD reason.",                     n = c("ops","icd"),                       sev = "Medium"),
  cat5_13 = list(w = "Skin graft OPS without wound/burn ICD.",                n = c("ops","icd"),                       sev = "Medium"),
  cat5_14 = list(w = "Upper GI endoscopy OPS without K-chapter ICD.",         n = c("ops","icd"),                       sev = "Medium"),
  cat5_15 = list(w = "Pacemaker OPS without I44-I49 ICD.",                    n = c("ops","icd"),                       sev = "Medium"),
  cat6_1  = list(w = "ICD code does not match valid syntax pattern.",         n = c("icd"),                             sev = "Medium"),
  cat6_2  = list(w = "OPS appears retired (heuristic).",                      n = c("ops"),                             sev = "Medium"),
  cat6_3  = list(w = "ICD potential typo (near-miss).",                       n = c("icd"),                             sev = "Medium"),
  cat6_4  = list(w = "Likely ICD-9 code in ICD-10 environment.",             n = c("icd"),                             sev = "Medium"),
  cat6_5  = list(w = "Placeholder/fake ICD (xxx, zzz).",                     n = c("icd"),                             sev = "High"),
  cat6_6  = list(w = "Numeric ICD-9 style code in ICD-10 env.",              n = c("icd"),                             sev = "Medium"),
  cat6_7  = list(w = "ICD length/shape out of range.",                       n = c("icd"),                             sev = "Medium"),
  cat6_8  = list(w = "OPS invalid structure.",                               n = c("ops"),                             sev = "Medium"),
  cat6_9  = list(w = "Foreign code system marker (z9).",                     n = c("icd","ops"),                       sev = "Low"),
  cat6_11 = list(w = "Unspecific ICD (R99, Z00).",                           n = c("icd"),                             sev = "Low")
)

mk_checks <- function() {
  ids <- names(CL)
  if (is.null(ids) || !length(ids)) return(data.frame())
  
  # ── Category derivation from check_id prefix ──
  derive_category <- function(id) {
    if (grepl("^cat1_", id)) return("Completeness")
    if (grepl("^cat2_", id)) return("Age Plausibility")
    if (grepl("^cat3_", id)) return("Gender Plausibility")
    if (grepl("^cat4_", id)) return("Temporal Consistency")
    if (grepl("^cat5_", id)) return("Diagnosis-Procedure")
    if (grepl("^cat6_", id)) return("Code Integrity")
    "Custom"
  }
  
  make_name <- function(id, w) {
    w <- as.character(w %||% id)
    if (grepl("^cat1_", id)) return(paste0("Completeness: ", w))
    if (grepl("^cat2_", id)) return(paste0("Age plausibility: ", w))
    if (grepl("^cat3_", id)) return(paste0("Gender plausibility: ", w))
    if (grepl("^cat4_", id)) return(paste0("Temporal consistency: ", w))
    if (grepl("^cat5_", id)) return(paste0("Dx-Procedure consistency: ", w))
    if (grepl("^cat6_", id)) return(paste0("Code integrity: ", w))
    w
  }
  
  data.frame(
    check_id   = ids,
    check_name = vapply(ids, function(id) make_name(id, CL[[id]]$w), character(1)),
    description = vapply(ids, function(id) CL[[id]]$w, character(1)),
    required   = vapply(ids, function(id) paste(CL[[id]]$n, collapse = ", "), character(1)),
    severity   = vapply(ids, function(id) CL[[id]]$sev %||% "Medium", character(1)),
    category   = vapply(ids, function(id) derive_category(id), character(1)),
    stringsAsFactors = FALSE
  )
}


# ── Section 7: Word Report Generation ────────────────────────────────────────
# Creates professional Word documents with officer + flextable.

# ── Section 7: Word Report Generation (V0.1 – Structured Proof Document) ─────
# Creates a publication-ready, IT-security-grade DQA proof document.
# Includes: tool metadata, assessment parameters, every check with description
# and result, severity analysis, and cryptographic session fingerprint.

gen_word <- function(issues, n_checks, mapped_df, lang = "en",
                     sev_plot = NULL, cat_plot = NULL,
                     user_info = NULL, perf_data = NULL,
                     checks_df = NULL, selected_checks = character(),
                     custom_checks = list(), cat_plot_file = NULL) {
  
  doc <- officer::read_docx()
  n_total <- if (!is.null(mapped_df)) nrow(mapped_df) else 0L
  n_cols  <- if (!is.null(mapped_df)) ncol(mapped_df) else 0L
  q <- calc_quality_score(n_total, issues)
  ts_now <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
  
  # ── Cryptographic session fingerprint ──
  session_hash <- tryCatch({
    raw_str <- paste0(n_total, "|", n_cols, "|", n_checks, "|",
                      q$score, "|", format(Sys.time(), "%Y%m%d%H%M%S"))
    digest_val <- paste(chartr("0123456789abcdef", "ABCDEF0123456789",
                               sprintf("%02x", as.integer(charToRaw(raw_str)))), collapse = "")
    substr(paste0("ODQA-", toupper(substr(digest_val, 1, 16))), 1, 21)
  }, error = function(e) paste0("ODQA-", format(Sys.time(), "%Y%m%d%H%M%S")))
  
  # Helper: page-safe flextable
  safe_ft <- function(ft) {
    ft |> flextable::set_table_properties(layout = "autofit", width = 1)
  }
  
  # ════════════════════════════════════════════════════════════════════════════
  # COVER / TITLE
  # ════════════════════════════════════════════════════════════════════════════
  doc <- officer::body_add_par(doc, "Data Quality Assessment Report", style = "heading 1")
  doc <- officer::body_add_par(doc, "Proof of Systematic Data Quality Assessment", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0("Session ID: ", session_hash), style = "Normal")
  doc <- officer::body_add_par(doc, paste0("Generated: ", ts_now), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  # ════════════════════════════════════════════════════════════════════════════
  # TOOL METADATA
  # ════════════════════════════════════════════════════════════════════════════
  doc <- officer::body_add_par(doc, "Tool Information", style = "heading 1")
  
  tool_meta <- data.frame(
    Property = c("Tool", "Version", "License", "R Version",
                 "Document ID", "Timestamp"),
    Value = c("Open DQA", "V0.1", "MIT License",
              paste0(R.version$major, ".", R.version$minor),
              session_hash, ts_now),
    stringsAsFactors = FALSE
  )
  ft <- flextable::flextable(tool_meta) |>
    flextable::autofit() |>
    flextable::theme_zebra() |>
    flextable::bold(j = 1) |>
    flextable::set_header_labels(Property = "Property", Value = "Value")
  doc <- flextable::body_add_flextable(doc, safe_ft(ft))
  doc <- officer::body_add_par(doc, "")
  
  doc <- officer::body_add_par(doc, "Data Protection Statement", style = "heading 2")
  doc <- officer::body_add_par(doc,
                               "This report intentionally excludes patient identifiers and row-level patient listings. Open DQA is a research tool (not a medical device under EU MDR, FDA, or equivalent). Results are intended for research-quality orientation and audit support. The user is solely responsible for validating and interpreting all results.",
                               style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  # ════════════════════════════════════════════════════════════════════════════
  # DATASET SUMMARY
  # ════════════════════════════════════════════════════════════════════════════
  doc <- officer::body_add_par(doc, "Dataset Summary", style = "heading 1")
  
  ds_meta <- data.frame(
    Parameter = c("Total Records (rows)", "Total Columns", "Checks Executed",
                  "Custom Checks", "Records With Issues", "Total Issues Found",
                  "Quality Score"),
    Value = c(as.character(n_total), as.character(n_cols), as.character(n_checks),
              as.character(length(custom_checks)),
              as.character(q$affected_rows), as.character(q$issue_count),
              paste0(q$score, "%")),
    stringsAsFactors = FALSE
  )
  ft2 <- flextable::flextable(ds_meta) |>
    flextable::autofit() |>
    flextable::theme_zebra() |>
    flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft2))
  doc <- officer::body_add_par(doc, "")
  
  doc <- officer::body_add_par(doc, "Quality Score Interpretation", style = "heading 2")
  doc <- officer::body_add_par(doc,
                               "Quality Score = 100% x (1 - affected_records / total_records). Color bands: Green 100-80%, Yellow 79-60%, Orange 59-40%, Red <40%. This is an orientation metric; domain-specific thresholds may apply.",
                               style = "Normal")
  
  band <- score_band(q$score)
  interp <- switch(band,
                   green  = "Excellent: All or nearly all records passed quality checks. Data is suitable for analysis.",
                   yellow = "Minor issues detected. Mostly informational; unlikely to significantly affect results.",
                   orange = "Moderate issues present. May introduce bias. Targeted cleansing is recommended.",
                   red    = "Significant or critical issues detected. Cleansing is strongly recommended before analysis.")
  doc <- officer::body_add_par(doc, paste0("Assessment: ", interp), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  # ════════════════════════════════════════════════════════════════════════════
  # METHODS
  # ════════════════════════════════════════════════════════════════════════════
  doc <- officer::body_add_par(doc, "Methods", style = "heading 1")
  
  doc <- officer::body_add_par(doc, "Assessment Framework", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "Data quality was assessed using Open DQA, an open-source platform that implements a ",
    "fitness-for-purpose evaluation strategy: rather than applying a fixed quality threshold, ",
    "data quality is systematically evaluated against the specific requirements of the research ",
    "question at hand (Wang & Strong, 1996; Weiskopf & Weng, 2013). This approach aligns with ",
    "the data quality dimensions defined in the TMF/DACH guidelines and the HIDQF framework for ",
    "health data."
  ), style = "Normal")
  
  doc <- officer::body_add_par(doc, "Integrated Check Library", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "The platform provides ", length(CL), " built-in rule-based checks organized into six ",
    "clinically validated categories: (1) Completeness \u2013 detection of missing diagnoses, ",
    "procedures, or coded entries when clinical documentation suggests their presence; ",
    "(2) Age Plausibility \u2013 identification of age-diagnosis combinations that fall outside ",
    "clinically expected ranges; (3) Gender Plausibility \u2013 flagging of sex-specific diagnoses ",
    "or procedures assigned to the biologically implausible sex; (4) Temporal Consistency \u2013 ",
    "verification of chronological integrity across admission, discharge, and birth dates; ",
    "(5) Diagnosis-Procedure Concordance \u2013 cross-validation between ICD-10 diagnoses and ",
    "OPS procedure codes to detect orphan entries; and (6) Code Integrity \u2013 syntactic and ",
    "structural validation of ICD-10 and OPS codes, including detection of retired codes, ",
    "format violations, and potential classification-system mismatches. Each check is classified ",
    "by severity (Critical, High, Medium, Low) and maps to one or more required data columns."
  ), style = "Normal")
  
  doc <- officer::body_add_par(doc, "Custom Fitness-for-Purpose Check Builder", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "Beyond the integrated library, researchers can construct domain-specific quality checks ",
    "using a visual rule builder that supports 17 logical operators: six comparison operators ",
    "(==, !=, >, >=, <, <=), four string-matching operators (contains, not_contains, ",
    "starts_with, ends_with), two presence operators (is.na, is_not.na), two range operators ",
    "(BETWEEN, NOT BETWEEN), two set-membership operators (IN, NOT IN), and one pattern-matching ",
    "operator (REGEXP). Conditions may be combined with AND/OR connectives into compound Boolean ",
    "expressions of arbitrary complexity, enabling researchers to encode study-specific inclusion ",
    "criteria, protocol-defined plausibility rules, or site-specific coding conventions. Custom ",
    "checks can be exported and imported as JSON for cross-project reuse and collaborative ",
    "standardization."
  ), style = "Normal")
  
  doc <- officer::body_add_par(doc, "ML-Assisted Anomaly Detection", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "An optional machine-learning module complements the rule-based approach by applying ",
    "unsupervised clustering (k-medoids via the PAM algorithm from the R 'cluster' package) ",
    "to the numeric and encoded categorical features of the dataset. Records assigned to ",
    "statistically small clusters\u2014defined as clusters whose membership falls below a ",
    "configurable percentile threshold\u2014are flagged as potential anomalies for human review. ",
    "This data-driven approach surfaces patterns that may not be captured by predefined rules, ",
    "such as atypical co-occurrence patterns, distributional outliers, or latent subgroups. ",
    "The ML suggestions serve as advisory inputs and require explicit researcher confirmation ",
    "before inclusion in the formal assessment."
  ), style = "Normal")
  
  doc <- officer::body_add_par(doc, "Evaluation and Scoring", style = "heading 2")
  doc <- officer::body_add_par(doc, paste0(
    "All checks\u2014built-in, custom, and ML-suggested\u2014are evaluated as logical R expressions ",
    "where TRUE denotes a rule violation. The resulting quality score is computed as: ",
    "Q = 100 \u00d7 (1 \u2013 affected_records / total_records), reported as a percentage with ",
    "color-coded severity bands (Green \u2265 80%, Yellow \u2265 60%, Orange \u2265 40%, Red < 40%). ",
    "Per-check impact metrics (affected count, percentage, severity) are reported individually ",
    "to enable targeted cleansing prioritization."
  ), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  # ════════════════════════════════════════════════════════════════════════════
  # RESULTS OVERVIEW
  # ════════════════════════════════════════════════════════════════════════════
  doc <- officer::body_add_par(doc, "Results Overview", style = "heading 1")
  
  if (!is.null(issues) && nrow(issues) > 0) {
    doc <- officer::body_add_par(doc, "Severity Distribution", style = "heading 2")
    sev <- sort(table(issues$severity), decreasing = TRUE)
    sev_df <- data.frame(Severity = names(sev), Count = as.integer(sev),
                         Percentage = paste0(round(100 * as.integer(sev) / nrow(issues), 1), "%"),
                         stringsAsFactors = FALSE)
    ft3 <- flextable::flextable(sev_df) |> flextable::autofit() |> flextable::theme_zebra()
    doc <- flextable::body_add_flextable(doc, safe_ft(ft3))
    
    if (!is.null(sev_plot) && file.exists(sev_plot)) {
      doc <- officer::body_add_par(doc, "")
      doc <- officer::body_add_img(doc, src = sev_plot, width = 6.5, height = 2.5)
    }
    doc <- officer::body_add_par(doc, "")
    
    doc <- officer::body_add_par(doc, "Category Distribution", style = "heading 2")
    if (!is.null(checks_df)) {
      issues$category <- checks_df$category[match(issues$check_id, checks_df$check_id)]
      issues$category[is.na(issues$category)] <- "Custom"
    } else {
      issues$category <- "Unclassified"
    }
    ct <- sort(table(issues$category), decreasing = TRUE)
    ct_df <- data.frame(Category = names(ct), Count = as.integer(ct),
                        Percentage = paste0(round(100 * as.integer(ct) / nrow(issues), 1), "%"),
                        stringsAsFactors = FALSE)
    ft4 <- flextable::flextable(ct_df) |> flextable::autofit() |> flextable::theme_zebra()
    doc <- flextable::body_add_flextable(doc, safe_ft(ft4))
    
    # Use cat_plot_file if provided (new param), otherwise fallback
    cat_plot_path <- cat_plot_file %||% cat_plot
    if (!is.null(cat_plot_path) && file.exists(cat_plot_path)) {
      doc <- officer::body_add_par(doc, "")
      doc <- officer::body_add_img(doc, src = cat_plot_path, width = 6.5, height = 2.5)
    }
  } else {
    doc <- officer::body_add_par(doc, "No issues detected by selected checks. All records passed.", style = "Normal")
  }
  doc <- officer::body_add_par(doc, "")
  
  # ════════════════════════════════════════════════════════════════════════════
  # COMPLETE CHECK REGISTER
  # ════════════════════════════════════════════════════════════════════════════
  doc <- officer::body_add_par(doc, "Complete Check Register", style = "heading 1")
  doc <- officer::body_add_par(doc, paste0(
    "The following table constitutes a complete, item-level register of every quality check ",
    "executed during this assessment session. For each check, the register records its unique ",
    "identifier, category, description, severity classification, required input columns, the ",
    "number and proportion of affected records, and the pass/fail result. This register serves ",
    "as the formal proof of systematic data quality assessment and satisfies documentation ",
    "requirements under ICH E6(R2) and institutional research data governance policies."
  ), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  # ── Register Execution Summary ──
  n_builtin   <- length(selected_checks)
  n_custom    <- length(custom_checks)
  n_total_chk <- n_builtin + n_custom
  
  doc <- officer::body_add_par(doc, "Execution Summary", style = "heading 2")
  exec_df <- data.frame(
    Metric = c("Built-in checks executed", "Custom checks executed",
               "Total checks executed", "Total records evaluated",
               "Records with at least one issue",
               "Overall quality score"),
    Value = c(as.character(n_builtin), as.character(n_custom),
              as.character(n_total_chk), as.character(n_total),
              as.character(q$affected_rows),
              paste0(q$score, "%")),
    stringsAsFactors = FALSE
  )
  ft_exec <- flextable::flextable(exec_df) |>
    flextable::autofit() |>
    flextable::theme_zebra() |>
    flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_exec))
  doc <- officer::body_add_par(doc, "")
  
  # ── Detailed Register Table ──
  doc <- officer::body_add_par(doc, "Detailed Check Register", style = "heading 2")
  
  if (!is.null(checks_df) && nrow(checks_df) > 0) {
    sel_df <- checks_df[checks_df$check_id %in% selected_checks, , drop = FALSE]
    sumdf <- issues_by_check(issues, checks_df, n_total)
    
    reg <- data.frame(
      Check_ID = sel_df$check_id,
      Category = if ("category" %in% names(sel_df)) sel_df$category else "Unclassified",
      Description = substr(as.character(sel_df$description), 1, 60),
      Severity = sel_df$severity,
      Required_Columns = sel_df$required,
      stringsAsFactors = FALSE
    )
    
    if (!is.null(sumdf) && nrow(sumdf) > 0) {
      aff <- sumdf[, c("check_id", "affected_n", "affected_pct")]
      names(aff) <- c("Check_ID", "Affected_Rows", "Affected_Pct")
      reg <- merge(reg, aff, by = "Check_ID", all.x = TRUE)
    } else {
      reg$Affected_Rows <- 0L
      reg$Affected_Pct <- 0.0
    }
    reg$Affected_Rows[is.na(reg$Affected_Rows)] <- 0L
    reg$Affected_Pct[is.na(reg$Affected_Pct)] <- 0.0
    reg$Result <- ifelse(reg$Affected_Rows == 0, "PASS", "ISSUES FOUND")
    
    if (length(custom_checks) > 0) {
      for (cc in custom_checks) {
        cc_id <- cc$check_id %||% "custom"
        cc_aff <- 0L; cc_pct <- 0.0
        if (!is.null(sumdf)) {
          row <- sumdf[sumdf$check_id == cc_id, , drop = FALSE]
          if (nrow(row) > 0) { cc_aff <- row$affected_n[1]; cc_pct <- row$affected_pct[1] }
        }
        reg <- rbind(reg, data.frame(
          Check_ID = cc_id,
          Category = "Custom",
          Description = substr(cc$description %||% "Custom check", 1, 60),
          Severity = cc$severity %||% "Medium",
          Required_Columns = "Custom",
          Affected_Rows = as.integer(cc_aff),
          Affected_Pct = cc_pct,
          Result = if (cc_aff == 0) "PASS" else "ISSUES FOUND",
          stringsAsFactors = FALSE
        ))
      }
    }
    
    reg$Affected_Pct <- paste0(round(reg$Affected_Pct, 2), "%")
    names(reg) <- c("Check ID", "Category", "Description", "Severity",
                    "Required Columns", "Affected Rows", "Affected %", "Result")
    
    ft5 <- flextable::flextable(reg) |>
      flextable::autofit() |>
      flextable::theme_zebra() |>
      flextable::bold(j = 8) |>
      flextable::fontsize(size = 7, part = "body") |>
      flextable::color(i = ~ `Result` == "ISSUES FOUND", j = 8, color = "#dc2626") |>
      flextable::color(i = ~ `Result` == "PASS", j = 8, color = "#16a34a")
    doc <- flextable::body_add_flextable(doc, safe_ft(ft5))
    
    # ── Category Breakdown ──
    doc <- officer::body_add_par(doc, "")
    doc <- officer::body_add_par(doc, "Results by Category", style = "heading 2")
    cat_summary <- as.data.frame(table(reg$Category), stringsAsFactors = FALSE)
    names(cat_summary) <- c("Category", "Checks_Executed")
    pass_counts <- tapply(reg$Result == "PASS", reg$Category, sum, na.rm = TRUE)
    fail_counts <- tapply(reg$Result == "ISSUES FOUND", reg$Category, sum, na.rm = TRUE)
    cat_summary$Passed <- as.integer(pass_counts[cat_summary$Category])
    cat_summary$Failed <- as.integer(fail_counts[cat_summary$Category])
    cat_summary$Passed[is.na(cat_summary$Passed)] <- 0L
    cat_summary$Failed[is.na(cat_summary$Failed)] <- 0L
    cat_summary$Pass_Rate <- paste0(round(100 * cat_summary$Passed / cat_summary$Checks_Executed, 1), "%")
    names(cat_summary) <- c("Category", "Checks Executed", "Passed", "Failed", "Pass Rate")
    
    ft_cat <- flextable::flextable(cat_summary) |>
      flextable::autofit() |>
      flextable::theme_zebra() |>
      flextable::bold(j = 1)
    doc <- flextable::body_add_flextable(doc, safe_ft(ft_cat))
    
  } else {
    doc <- officer::body_add_par(doc, paste0(
      "No check register is available. This may occur when no checks were selected for execution ",
      "or when the report was generated from a session that did not complete the assessment workflow. ",
      "To generate a complete register, select checks in Step 3 and execute the assessment before ",
      "downloading the report."
    ), style = "Normal")
  }
  doc <- officer::body_add_par(doc, "")
  
  # ════════════════════════════════════════════════════════════════════════════
  # PER-CHECK IMPACT ANALYSIS (limited to top 15)
  # ════════════════════════════════════════════════════════════════════════════
  doc <- officer::body_add_par(doc, "Per-Check Impact Analysis", style = "heading 1")
  
  sumdf2 <- issues_by_check(issues, checks_df %||% mk_checks(), n_total)
  if (!is.null(sumdf2) && nrow(sumdf2) > 0) {
    # Summary table first
    impact_tbl <- data.frame(
      Check = paste0("[", sumdf2$check_id, "] ", sumdf2$check_name %||% sumdf2$check_id),
      Severity = sumdf2$severity,
      Affected = sumdf2$affected_n,
      Pct = paste0(sumdf2$affected_pct, "%"),
      stringsAsFactors = FALSE
    )
    ft_impact <- flextable::flextable(impact_tbl[seq_len(min(nrow(impact_tbl), 30)), ]) |>
      flextable::autofit() |>
      flextable::theme_zebra() |>
      flextable::fontsize(size = 7, part = "body")
    doc <- flextable::body_add_flextable(doc, safe_ft(ft_impact))
    doc <- officer::body_add_par(doc, "")
    
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
        save_png_plot(
          paste0("check_", gsub("[^a-zA-Z0-9]", "_", cid), ".png"),
          function() plot_check_impact(an, n_total, paste0("[", cid, "] ", nm),
                                       paste0("Affected: ", an, " (", ap, "%) | Severity: ", sev))
        ), error = function(e) NULL)
      
      if (!is.null(pth) && file.exists(pth)) {
        doc <- officer::body_add_img(doc, src = pth, width = 6.5, height = 2.4)
      }
    }
    if (nrow(sumdf2) > 15) {
      doc <- officer::body_add_par(doc, paste0("... and ", nrow(sumdf2) - 15, " additional checks (see summary table above)."), style = "Normal")
    }
  } else {
    doc <- officer::body_add_par(doc, "No checks produced issues. All records passed.", style = "Normal")
  }
  doc <- officer::body_add_par(doc, "")
  
  # ════════════════════════════════════════════════════════════════════════════
  # PROCESSING & AUDIT INFORMATION
  # ════════════════════════════════════════════════════════════════════════════
  doc <- officer::body_add_par(doc, "Processing & Audit Information", style = "heading 1")
  doc <- officer::body_add_par(doc, paste0(
    "This section provides a complete audit trail of all processing activities performed ",
    "during this data quality assessment session. It is intended to satisfy traceability ",
    "requirements under ICH E6(R2) Section 5.5.3 and institutional research data governance policies."
  ), style = "Normal")
  doc <- officer::body_add_par(doc, "")
  
  # ── Session Environment ──
  doc <- officer::body_add_par(doc, "Session Environment", style = "heading 2")
  env_df <- data.frame(
    Property = c(
      "R Version",
      "Platform",
      "Operating System",
      "Locale",
      "Timezone",
      "Open DQA Version",
      "Session ID",
      "Report Timestamp (ISO 8601)"
    ),
    Value = c(
      paste0(R.version$major, ".", R.version$minor, " (", R.version$nickname, ")"),
      R.version$platform,
      tryCatch(utils::sessionInfo()$running, error = function(e) Sys.info()[["sysname"]]),
      tryCatch(Sys.getlocale("LC_CTYPE"), error = function(e) "Unknown"),
      Sys.timezone(),
      "V0.1",
      session_hash,
      format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    ),
    stringsAsFactors = FALSE
  )
  ft_env <- flextable::flextable(env_df) |>
    flextable::autofit() |>
    flextable::theme_zebra() |>
    flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_env))
  doc <- officer::body_add_par(doc, "")
  
  # ── Analyst Attribution ──
  doc <- officer::body_add_par(doc, "Analyst Attribution", style = "heading 2")
  ui_name  <- tryCatch(user_info$name,  error = function(e) "")
  ui_func  <- tryCatch(user_info$func,  error = function(e) "")
  ui_email <- tryCatch(user_info$email, error = function(e) "")
  if (is.null(ui_name) || !nzchar(trimws(ui_name %||% ""))) ui_name <- "Not provided"
  if (is.null(ui_func) || !nzchar(trimws(ui_func %||% ""))) ui_func <- "Not provided"
  if (is.null(ui_email) || !nzchar(trimws(ui_email %||% ""))) ui_email <- "Not provided"
  
  analyst_df <- data.frame(
    Field = c("Name", "Function / Role", "Email"),
    Value = c(ui_name, ui_func, ui_email),
    stringsAsFactors = FALSE
  )
  ft_analyst <- flextable::flextable(analyst_df) |>
    flextable::autofit() |>
    flextable::theme_zebra() |>
    flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_analyst))
  doc <- officer::body_add_par(doc, "")
  
  # ── Performance Timeline ──
  doc <- officer::body_add_par(doc, "Performance Timeline", style = "heading 2")
  if (!is.null(perf_data) && is.data.frame(perf_data) && nrow(perf_data) > 0) {
    perf_display <- perf_data
    names(perf_display) <- c("Task", "Source / Scope", "Records", "Duration (sec)", "Timestamp")
    ft_perf <- flextable::flextable(perf_display) |>
      flextable::autofit() |>
      flextable::theme_zebra() |>
      flextable::fontsize(size = 8, part = "body") |>
      flextable::bold(j = 1)
    doc <- flextable::body_add_flextable(doc, safe_ft(ft_perf))
    doc <- officer::body_add_par(doc, "")
    
    total_dur <- sum(perf_data$duration_sec, na.rm = TRUE)
    doc <- officer::body_add_par(doc, paste0(
      "Total processing time: ", round(total_dur, 3), " seconds across ",
      nrow(perf_data), " recorded task(s)."
    ), style = "Normal")
  } else {
    doc <- officer::body_add_par(doc,
                                 "No performance timing data was recorded for this session. This may occur when the report is generated from the summary page without a preceding full assessment workflow.",
                                 style = "Normal")
  }
  doc <- officer::body_add_par(doc, "")
  
  # ── Data Integrity Fingerprint ──
  doc <- officer::body_add_par(doc, "Data Integrity Verification", style = "heading 2")
  data_fp <- tryCatch({
    if (!is.null(mapped_df) && nrow(mapped_df) > 0) {
      col_sig <- paste(names(mapped_df), collapse = "|")
      dim_sig <- paste0(nrow(mapped_df), "x", ncol(mapped_df))
      sample_vals <- paste(head(unlist(mapped_df[1, ]), 5), collapse = ",")
      raw_fp <- paste0(col_sig, "|", dim_sig, "|", sample_vals, "|", n_checks)
      hex_chars <- sprintf("%02x", as.integer(charToRaw(raw_fp)))
      paste0("DF-", toupper(paste(hex_chars[seq_len(min(20, length(hex_chars)))], collapse = "")))
    } else {
      "DF-EMPTY"
    }
  }, error = function(e) "DF-ERROR")
  
  integrity_df <- data.frame(
    Property = c(
      "Dataset Fingerprint",
      "Dataset Dimensions",
      "Checks Executed",
      "Session Hash",
      "Fingerprint Method"
    ),
    Value = c(
      data_fp,
      paste0(n_total, " rows \u00d7 ", n_cols, " columns"),
      as.character(n_checks),
      session_hash,
      "charToRaw() hex encoding of column-signature + dimensions + first-row sample"
    ),
    stringsAsFactors = FALSE
  )
  ft_integrity <- flextable::flextable(integrity_df) |>
    flextable::autofit() |>
    flextable::theme_zebra() |>
    flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_integrity))
  doc <- officer::body_add_par(doc, "")
  
  # ════════════════════════════════════════════════════════════════════════════
  # CERTIFICATION FOOTER
  # ════════════════════════════════════════════════════════════════════════════
  doc <- officer::body_add_par(doc, "Certification", style = "heading 1")
  doc <- officer::body_add_par(doc,
                               paste0("This document certifies that a systematic data quality assessment was performed using Open DQA V0.1 (Session: ", session_hash, "). ",
                                      "The assessment covered ", n_checks, " checks across ", n_total, " records. ",
                                      "The resulting Quality Score is ", q$score, "%. ",
                                      "This report was auto-generated and has not been manually modified."),
                               style = "Normal")
  doc <- officer::body_add_par(doc, "")
  doc <- officer::body_add_par(doc, paste0("Report generated: ", ts_now), style = "Normal")
  doc <- officer::body_add_par(doc, "Open DQA V0.1 | MIT License | Heidelberg University MIISM", style = "Normal")
  
  doc
}

gen_cl_word <- function(cl, l = "en", user_info = NULL) {
  doc <- officer::read_docx()
  ts_now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  
  # ── Cryptographic integrity hash ──
  cl_hash <- tryCatch({
    raw_str <- paste0(nrow(cl), "|", ts_now, "|",
                      paste(names(cl), collapse = ","), "|",
                      if (nrow(cl) > 0) paste(cl$Timestamp[1], cl$Timestamp[nrow(cl)]) else "empty")
    hex_chars <- sprintf("%02x", as.integer(charToRaw(raw_str)))
    paste0("CL-", toupper(paste(hex_chars[seq_len(min(12, length(hex_chars)))], collapse = "")))
  }, error = function(e) paste0("CL-", format(Sys.time(), "%Y%m%d%H%M%S")))
  
  # Helper: page-safe flextable
  safe_ft <- function(ft) {
    ft |> flextable::set_table_properties(layout = "autofit", width = 1)
  }
  
  # ════════════════════════════════════════════════════════════════════════════
  # COVER
  # ════════════════════════════════════════════════════════════════════════════
  doc <- doc |>
    officer::body_add_par("Data Cleansing Change Log", style = "heading 1") |>
    officer::body_add_par(paste0("Document ID: ", cl_hash), style = "Normal") |>
    officer::body_add_par(paste0("Generated: ", ts_now, " (ISO 8601)"), style = "Normal") |>
    officer::body_add_par("Open DQA V0.1 | MIT License", style = "Normal") |>
    officer::body_add_par("")
  
  # ════════════════════════════════════════════════════════════════════════════
  # PURPOSE & SCOPE
  # ════════════════════════════════════════════════════════════════════════════
  doc <- doc |>
    officer::body_add_par("Purpose and Scope", style = "heading 1") |>
    officer::body_add_par(paste0(
      "This document provides a complete, immutable record of all data modifications ",
      "performed during the cleansing process. It is designed to satisfy documentation ",
      "requirements for: (a) Good Clinical Practice (ICH E6(R2), Section 5.5.3 ",
      "- data handling and record keeping), (b) EU General Data Protection Regulation ",
      "(GDPR Art. 5(1)(d) - accuracy principle), (c) ISO 14155:2020 (clinical investigation ",
      "of medical devices - data management), (d) OECD Principles of Good Laboratory Practice, ",
      "and (e) institutional research data management policies. Each entry records the exact ",
      "timestamp, action, affected column, row scope, and old/new values to enable full ",
      "audit trail reconstruction."
    ), style = "Normal") |>
    officer::body_add_par("")
  
  # ════════════════════════════════════════════════════════════════════════════
  # REGULATORY CONTEXT
  # ════════════════════════════════════════════════════════════════════════════
  doc <- doc |>
    officer::body_add_par("Regulatory Context", style = "heading 1")
  
  reg_df <- data.frame(
    Framework = c("ICH E6(R2) GCP", "GDPR Art. 5(1)(d)", "FAIR Principles",
                  "FDA 21 CFR Part 11", "ISO 14155:2020", "OECD GLP"),
    Requirement = c(
      "Complete audit trail for data corrections in clinical trials",
      "Personal data must be accurate and kept up to date",
      "Research data should be Findable, Accessible, Interoperable, Reusable",
      "Electronic records must include audit trails with date/time stamps",
      "Documented data management procedures for clinical investigations",
      "Raw data changes must be traceable with reason for change"
    ),
    Addressed = c("Full timestamp + old/new value logging",
                  "Documented justification for each correction",
                  "Machine-readable change log with unique document ID",
                  "ISO 8601 timestamps, integrity hash, sequential logging",
                  "Structured modification register with sequential numbering",
                  "Before/after values preserved with action classification"),
    stringsAsFactors = FALSE
  )
  ft_reg <- flextable::flextable(reg_df) |>
    flextable::autofit() |>
    flextable::theme_zebra() |>
    flextable::bold(j = 1) |>
    flextable::fontsize(size = 8, part = "body")
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_reg))
  doc <- officer::body_add_par(doc, "")
  
  # ════════════════════════════════════════════════════════════════════════════
  # TOOL INFORMATION
  # ════════════════════════════════════════════════════════════════════════════
  doc <- doc |>
    officer::body_add_par("Tool Information", style = "heading 1")
  
  tool_df <- data.frame(
    Property = c("Tool", "Version", "License", "R Version",
                 "Document ID", "Timestamp"),
    Value = c("Open DQA", "V0.1", "MIT License",
              paste0(R.version$major, ".", R.version$minor),
              cl_hash, ts_now),
    stringsAsFactors = FALSE
  )
  ft_tool <- flextable::flextable(tool_df) |>
    flextable::autofit() |>
    flextable::theme_zebra() |>
    flextable::bold(j = 1)
  doc <- flextable::body_add_flextable(doc, safe_ft(ft_tool))
  doc <- officer::body_add_par(doc, "")
  
  # ── Analyst Information (if provided) ──
  if (!is.null(user_info) && nzchar(user_info$name %||% "")) {
    doc <- officer::body_add_par(doc, "Analyst Information", style = "heading 2")
    adf <- data.frame(
      Field = c("Name", "Function", "Email"),
      Value = c(user_info$name %||% "", user_info$func %||% "",
                user_info$email %||% ""),
      stringsAsFactors = FALSE
    )
    ft_a <- flextable::flextable(adf) |> flextable::autofit() |> flextable::theme_zebra()
    doc <- flextable::body_add_flextable(doc, safe_ft(ft_a))
    doc <- officer::body_add_par(doc, "")
  }
  
  # ════════════════════════════════════════════════════════════════════════════
  # DATA PROCESSING LOG
  # ════════════════════════════════════════════════════════════════════════════
  doc <- doc |>
    officer::body_add_par("Data Processing Log", style = "heading 1")
  
  if (!is.null(cl) && nrow(cl) > 0) {
    # ── Summary Statistics ──
    doc <- officer::body_add_par(doc, "Summary Statistics", style = "heading 2")
    
    unique_actions <- length(unique(cl$Action))
    unique_cols <- length(unique(cl$Column[cl$Column != "--"]))
    first_ts <- cl$Timestamp[1]
    last_ts <- cl$Timestamp[nrow(cl)]
    
    sum_df <- data.frame(
      Metric = c("Total Modifications", "Unique Action Types",
                 "Columns Affected", "First Modification", "Last Modification"),
      Value = c(as.character(nrow(cl)), as.character(unique_actions),
                as.character(unique_cols), first_ts, last_ts),
      stringsAsFactors = FALSE
    )
    ft_sum <- flextable::flextable(sum_df) |>
      flextable::autofit() |>
      flextable::theme_zebra() |>
      flextable::bold(j = 1)
    doc <- flextable::body_add_flextable(doc, safe_ft(ft_sum))
    doc <- officer::body_add_par(doc, "")
    
    # ── Complete Modification Register ──
    doc <- officer::body_add_par(doc, "Complete Modification Register", style = "heading 2")
    doc <- officer::body_add_par(doc, paste0(
      "The following table contains every data modification in chronological order. ",
      "Each entry is sequentially numbered for cross-referencing. ",
      "For large logs (>200 entries), the table is split into chunks to prevent page overflow."
    ), style = "Normal")
    doc <- officer::body_add_par(doc, "")
    
    cl_display <- as.data.frame(cl)
    cl_display <- cbind(Seq = seq_len(nrow(cl_display)), cl_display)
    
    # Truncate long values to prevent column overflow
    for (col_name in names(cl_display)) {
      if (is.character(cl_display[[col_name]])) {
        cl_display[[col_name]] <- substr(cl_display[[col_name]], 1, 80)
      }
    }
    
    # Chunked output for large logs
    chunk_size <- 200L
    n_chunks <- ceiling(nrow(cl_display) / chunk_size)
    for (ch in seq_len(n_chunks)) {
      start_row <- (ch - 1L) * chunk_size + 1L
      end_row <- min(ch * chunk_size, nrow(cl_display))
      chunk_df <- cl_display[start_row:end_row, , drop = FALSE]
      
      if (n_chunks > 1L) {
        doc <- officer::body_add_par(doc, paste0(
          "Entries ", start_row, " - ", end_row, " of ", nrow(cl_display)
        ), style = "Normal")
      }
      
      ft_cl <- flextable::flextable(chunk_df) |>
        flextable::autofit() |>
        flextable::theme_zebra() |>
        flextable::fontsize(size = 7, part = "body") |>
        flextable::fontsize(size = 8, part = "header") |>
        flextable::bold(part = "header")
      doc <- flextable::body_add_flextable(doc, safe_ft(ft_cl))
      doc <- officer::body_add_par(doc, "")
    }
  } else {
    doc <- officer::body_add_par(doc,
                                 "No modifications were performed during this cleansing session.", style = "Normal")
  }
  doc <- officer::body_add_par(doc, "")
  
  # ════════════════════════════════════════════════════════════════════════════
  # CERTIFICATION
  # ════════════════════════════════════════════════════════════════════════════
  doc <- doc |>
    officer::body_add_par("Certification and Archival", style = "heading 1") |>
    officer::body_add_par(paste0(
      "This document certifies that all data modifications listed above were performed ",
      "using Open DQA V0.1 and logged automatically. The document integrity hash is: ",
      cl_hash, ". This change log should be archived alongside the study documentation ",
      "and the cleansed dataset. For GCP-regulated studies, this document forms part of ",
      "the Trial Master File (TMF) data management section. For studies governed by ",
      "ISO 14155:2020 or OECD GLP, this log satisfies the requirement for traceable ",
      "raw data modifications."
    ), style = "Normal") |>
    officer::body_add_par("") |>
    officer::body_add_par(paste0("Report generated: ", ts_now), style = "Normal") |>
    officer::body_add_par("Open DQA V0.1 | MIT License | Heidelberg University MIISM", style = "Normal")
  
  doc
}

# ── Section 8: FAQ Data ──────────────────────────────────────────────────────

FAQ_DATA <- list(
  list(
    q = list(en = "What data formats does Open DQA support?", de = "Welche Datenformate unterst\u00fctzt Open DQA?", fr = "Quels formats de donn\u00e9es Open DQA prend-il en charge ?"),
    a = list(en = "CSV/TXT (comma, semicolon, or tab-separated), Excel (.xlsx/.xls), JSON (standard arrays or NDJSON), FHIR R4 Bundles, and direct SQL connections to PostgreSQL and Microsoft SQL Server databases. Large files (millions of rows) are handled via data.table for efficient memory usage.", de = "CSV/TXT, Excel, JSON, FHIR R4 Bundles und direkte SQL-Verbindungen zu PostgreSQL und Microsoft SQL Server. Gro\u00dfe Dateien werden effizient mit data.table verarbeitet.", fr = "CSV/TXT, Excel, JSON, FHIR R4 Bundles et connexions SQL directes \u00e0 PostgreSQL et Microsoft SQL Server. Les grands fichiers sont trait\u00e9s efficacement avec data.table.")
  ),
  list(
    q = list(en = "Is Open DQA limited to ICD-10-GM codes?", de = "Ist Open DQA auf ICD-10-GM beschr\u00e4nkt?", fr = "Open DQA est-il limit\u00e9 aux codes CIM-10-GM ?"),
    a = list(en = "No. The 77 built-in checks primarily target ICD-10 coded data and German OPS procedures, but many checks (completeness, temporal, code syntax) work with any ICD-10 variant. The Custom Rule Builder lets you create checks for any coding system including SNOMED CT, LOINC, Read Codes, or proprietary schemas.", de = "Nein. Die 77 Checks zielen haupts\u00e4chlich auf ICD-10 und OPS, aber viele funktionieren mit jeder ICD-10-Variante. Der Custom Rule Builder erm\u00f6glicht Pr\u00fcfungen f\u00fcr jedes Codiersystem.", fr = "Non. Les 77 v\u00e9rifications ciblent principalement ICD-10 et OPS, mais beaucoup fonctionnent avec toute variante CIM-10. Le constructeur de r\u00e8gles permet de cr\u00e9er des v\u00e9rifications pour tout syst\u00e8me.")
  ),
  list(
    q = list(en = "How is the Quality Score calculated?", de = "Wie wird der Quality Score berechnet?", fr = "Comment le score de qualit\u00e9 est-il calcul\u00e9 ?"),
    a = list(en = "Quality Score = 100% \u00d7 (1 \u2013 affected_records / total_records). A record counts as \u2018affected\u2019 if at least one check flagged it. 100% means no issues found. The formula is intentionally simple and transparent.", de = "Quality Score = 100% \u00d7 (1 \u2013 betroffene / Gesamt). Ein Datensatz z\u00e4hlt als betroffen, wenn mindestens ein Check ihn markiert hat.", fr = "Score = 100% \u00d7 (1 \u2013 affect\u00e9s / total). Un enregistrement est affect\u00e9 si au moins une v\u00e9rification l\u2019a signal\u00e9.")
  ),
  list(
    q = list(en = "Can I share my custom checks with colleagues?", de = "Kann ich eigene Checks mit Kollegen teilen?", fr = "Puis-je partager mes v\u00e9rifications avec des coll\u00e8gues ?"),
    a = list(en = "Yes. Export your custom checks as a JSON file and share it. Your colleagues import the file in Step 4, and all check definitions including names, expressions, severity, and creation timestamps are preserved.", de = "Ja. Exportieren Sie als JSON und teilen Sie die Datei. Alle Definitionen inklusive Zeitstempel bleiben erhalten.", fr = "Oui. Exportez en JSON et partagez. Toutes les d\u00e9finitions y compris horodatages sont conserv\u00e9es.")
  ),
  list(
    q = list(en = "Is the audit trail legally compliant?", de = "Ist der Audit-Trail rechtskonform?", fr = "La piste d\u2019audit est-elle conforme ?"),
    a = list(en = "Open DQA logs every data modification with timestamp, action, column, row, old value, and new value. This documentation supports GCP compliance and can be included as supplementary material in publications. However, Open DQA itself is not a certified GxP-validated system.", de = "Open DQA protokolliert jede Modifikation mit Zeitstempel, Aktion, Spalte, Zeile, altem und neuem Wert. Dies unterst\u00fctzt GCP-Konformit\u00e4t, aber Open DQA ist kein GxP-validiertes System.", fr = "Open DQA enregistre chaque modification avec horodatage, action, colonne, ligne, ancienne et nouvelle valeur. Cela soutient la conformit\u00e9 GCP, mais Open DQA n\u2019est pas un syst\u00e8me valid\u00e9 GxP.")
  ),
  list(
    q = list(en = "How large can my dataset be?", de = "Wie gro\u00df kann mein Datensatz sein?", fr = "Quelle taille peut avoir mon jeu de donn\u00e9es ?"),
    a = list(en = "Open DQA uses data.table internally for fast I/O and can handle datasets with millions of rows, limited only by available server RAM. For datasets exceeding available memory, consider using the SQL connection to query subsets directly from your database.", de = "Open DQA nutzt data.table und kann Millionen von Zeilen verarbeiten, begrenzt nur durch den verf\u00fcgbaren RAM. F\u00fcr noch gr\u00f6\u00dfere Datens\u00e4tze nutzen Sie die SQL-Verbindung.", fr = "Open DQA utilise data.table et peut traiter des millions de lignes, limit\u00e9 uniquement par la RAM. Pour de plus grands jeux, utilisez la connexion SQL.")
  ),
  list(
    q = list(en = "Can I use Open DQA for multi-centre studies?", de = "Kann ich Open DQA f\u00fcr multizentrische Studien nutzen?", fr = "Puis-je utiliser Open DQA pour des \u00e9tudes multicentriques ?"),
    a = list(en = "Yes. Each centre can run Open DQA independently and export their quality reports and cleaned datasets. Custom check JSON files can be shared across centres to ensure consistent validation rules.", de = "Ja. Jedes Zentrum kann Open DQA unabh\u00e4ngig nutzen und Berichte exportieren. JSON-Check-Dateien k\u00f6nnen zentren\u00fcbergreifend geteilt werden.", fr = "Oui. Chaque centre peut utiliser Open DQA ind\u00e9pendamment. Les fichiers JSON de v\u00e9rifications peuvent \u00eatre partag\u00e9s entre centres.")
  ),
  list(
    q = list(en = "Is my data sent to any server?", de = "Werden meine Daten an einen Server gesendet?", fr = "Mes donn\u00e9es sont-elles envoy\u00e9es \u00e0 un serveur ?"),
    a = list(en = "No. Open DQA runs entirely in your browser session (R Shiny). Your data stays on the machine running the app. Nothing is transmitted externally unless you explicitly use the SQL or FHIR server connection features.", de = "Nein. Open DQA l\u00e4uft vollst\u00e4ndig in Ihrer Browser-Sitzung. Ihre Daten bleiben auf Ihrem Rechner.", fr = "Non. Open DQA fonctionne enti\u00e8rement dans votre session navigateur. Vos donn\u00e9es restent sur votre machine.")
  ),
  list(
    q = list(en = "How do I cite Open DQA in publications?", de = "Wie zitiere ich Open DQA in Publikationen?", fr = "Comment citer Open DQA dans les publications ?"),
    a = list(en = "Please cite: Kamdje Wabo G, Sokolowski P, Ganslandt T, Siegel F. Open DQA: An Open-Source Platform for Clinical Data Quality Assessment. Heidelberg University, MIISM. 2026. Available at: [repository URL]. Include the quality report as supplementary material.", de = "Bitte zitieren Sie: Kamdje Wabo G, Sokolowski P, Ganslandt T, Siegel F. Open DQA. Universit\u00e4t Heidelberg, MIISM. 2026.", fr = "Veuillez citer : Kamdje Wabo G, Sokolowski P, Ganslandt T, Siegel F. Open DQA. Universit\u00e9 de Heidelberg, MIISM. 2026.")
  ),
  list(
    q = list(en = "Is Open DQA free to use?", de = "Ist Open DQA kostenlos?", fr = "Open DQA est-il gratuit ?"),
    a = list(en = "Yes. Open DQA is released under the MIT License. You can use, modify, and distribute it freely, including in commercial research settings. Attribution to the original authors is appreciated.", de = "Ja. Open DQA steht unter der MIT-Lizenz. Sie k\u00f6nnen es frei verwenden, modifizieren und verbreiten.", fr = "Oui. Open DQA est publi\u00e9 sous licence MIT. Vous pouvez l\u2019utiliser, le modifier et le distribuer librement.")
  )
)

# ── Section 9: CSS Design System ─────────────────────────────────────────────
# Professional, scholarly design with Inter font. Preserves original design language
# while adding new components for FAQ, finish page, guided cleansing.

APP_CSS <- "
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&display=swap');
:root{--brand:#0866FF;--brand-hover:#0753D4;--brand-light:#EBF5FF;--brand-surface:#F0F7FF;--brand-glow:rgba(8,102,255,0.12);--success:#00A86B;--success-light:#E6F9F0;--warning:#F5A623;--warning-light:#FFF8EC;--danger:#FA383E;--danger-light:#FFF0F0;--critical:#BE123C;--critical-light:#FFF1F2;--text-primary:#1C1E21;--text-secondary:#606770;--text-tertiary:#8A8D91;--surface-0:#FFF;--surface-1:#F0F2F5;--surface-2:#E4E6EB;--border:#CED0D4;--border-light:#E4E6EB;--shadow-xs:0 1px 2px rgba(0,0,0,0.04);--shadow-sm:0 1px 3px rgba(0,0,0,0.06),0 1px 2px rgba(0,0,0,0.04);--shadow-md:0 4px 6px -1px rgba(0,0,0,0.07),0 2px 4px -1px rgba(0,0,0,0.04);--shadow-lg:0 10px 25px -3px rgba(0,0,0,0.08),0 4px 10px -2px rgba(0,0,0,0.04);--shadow-xl:0 20px 40px -5px rgba(0,0,0,0.1);--radius-sm:8px;--radius-md:12px;--radius-lg:16px;--radius-xl:20px;--radius-2xl:24px;--transition:all 0.2s cubic-bezier(0.4,0,0.2,1)}
*,*::before,*::after{box-sizing:border-box}
body,.content-wrapper,.wrapper{font-family:'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif!important;background:var(--surface-1)!important;color:var(--text-primary);-webkit-font-smoothing:antialiased}
.main-sidebar,.main-header,.main-footer,.control-sidebar,.brand-link{display:none!important}
.content-wrapper{margin-left:0!important;padding:0!important;min-height:100vh!important}

/* ── Topbar ── */
.odqa-topbar{position:sticky;top:0;z-index:1040;display:flex;align-items:center;justify-content:space-between;height:60px;padding:0 24px;background:var(--surface-0);border-bottom:1px solid var(--border-light);box-shadow:var(--shadow-xs)}
.odqa-topbar-brand{display:flex;align-items:center;gap:10px;font-size:20px;font-weight:800;color:var(--brand);letter-spacing:-0.5px;cursor:pointer}
.odqa-topbar-brand .brand-icon{width:36px;height:36px;border-radius:10px;background:linear-gradient(135deg,var(--brand),#6C5CE7);display:flex;align-items:center;justify-content:center;color:white;font-size:16px;font-weight:900}
.odqa-topbar-nav{display:flex;align-items:center;gap:4px;background:var(--surface-1);border-radius:var(--radius-lg);padding:4px}
.odqa-nav-pill{padding:8px 16px;border-radius:var(--radius-md);font-size:13px;font-weight:600;color:var(--text-secondary);cursor:pointer;transition:var(--transition);border:none;background:transparent;white-space:nowrap}
.odqa-nav-pill:hover{background:var(--surface-2);color:var(--text-primary)}
.odqa-nav-pill.active{background:var(--brand)!important;color:white!important;box-shadow:0 2px 8px rgba(8,102,255,0.3)}
.odqa-nav-pill.disabled{opacity:0.4;pointer-events:none}
.odqa-topbar-actions{display:flex;align-items:center;gap:12px}

/* ── Steps ── */
.odqa-step{display:none;animation:fadeSlide 0.35s ease}.odqa-step.active{display:block}
@keyframes fadeSlide{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
.odqa-container{max-width:960px;margin:0 auto;padding:32px 24px 80px}
.odqa-container-wide{max-width:1200px;margin:0 auto;padding:32px 24px 80px}

/* ── Hero ── */
.odqa-hero{text-align:center;padding:56px 24px 40px;background:linear-gradient(135deg,#EBF5FF 0%,#F5F0FF 50%,#FFF0F5 100%);position:relative;overflow:hidden}
.odqa-hero::before{content:'';position:absolute;top:-50%;left:-50%;width:200%;height:200%;background:radial-gradient(circle at 30% 40%,rgba(8,102,255,0.06) 0%,transparent 50%),radial-gradient(circle at 70% 60%,rgba(108,92,231,0.05) 0%,transparent 50%);animation:heroShimmer 20s ease infinite}
@keyframes heroShimmer{0%,100%{transform:translate(0,0)}50%{transform:translate(-3%,2%)}}
.odqa-hero-content{position:relative;z-index:1}
.odqa-hero h1{font-size:42px;font-weight:900;letter-spacing:-1.5px;background:linear-gradient(135deg,var(--brand) 0%,#6C5CE7 100%);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;margin-bottom:12px}
.odqa-hero .subtitle{font-size:17px;color:var(--text-secondary);font-weight:400;max-width:600px;margin:0 auto 8px;line-height:1.6}
.odqa-hero .desc{font-size:14px;color:var(--text-tertiary);max-width:680px;margin:0 auto 36px;line-height:1.7}

/* ── Cards ── */
.odqa-action-cards{display:grid;grid-template-columns:1fr 1fr;gap:20px;max-width:720px;margin:0 auto 32px;position:relative;z-index:1}
.odqa-action-card{background:var(--surface-0);border-radius:var(--radius-xl);padding:28px 24px;text-align:left;border:2px solid transparent;cursor:pointer;box-shadow:var(--shadow-md);transition:var(--transition);position:relative;overflow:hidden}
.odqa-action-card:hover{transform:translateY(-4px);box-shadow:var(--shadow-xl);border-color:var(--brand)}
.odqa-action-card .card-icon{width:48px;height:48px;border-radius:var(--radius-md);display:flex;align-items:center;justify-content:center;font-size:22px;margin-bottom:14px}
.odqa-action-card.tutorial .card-icon{background:linear-gradient(135deg,#E8F5E9,#C8E6C9);color:var(--success)}
.odqa-action-card.start .card-icon{background:linear-gradient(135deg,#EBF5FF,#BBDEFB);color:var(--brand)}
.odqa-action-card h3{font-size:17px;font-weight:700;margin-bottom:6px}
.odqa-action-card p{font-size:13px;color:var(--text-secondary);line-height:1.5;margin:0}
.odqa-action-card .card-arrow{position:absolute;right:20px;top:50%;transform:translateY(-50%);font-size:20px;color:var(--text-tertiary);transition:var(--transition)}
.odqa-action-card:hover .card-arrow{color:var(--brand);transform:translateY(-50%) translateX(4px)}

/* ── Workflow ── */
.odqa-workflow{display:flex;justify-content:center;gap:0;max-width:800px;margin:0 auto 28px;position:relative;z-index:1}
.odqa-wf-step{display:flex;flex-direction:column;align-items:center;gap:8px;flex:1;position:relative}
.odqa-wf-num{width:34px;height:34px;border-radius:50%;background:var(--brand);color:white;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:14px}
.odqa-wf-label{font-size:11px;font-weight:600;color:var(--text-secondary);text-align:center;line-height:1.3}
.odqa-wf-step:not(:last-child)::after{content:'';position:absolute;top:17px;left:calc(50% + 20px);width:calc(100% - 40px);height:2px;background:var(--border)}

/* ── Trust counter ── */
.odqa-trust{display:flex;align-items:center;justify-content:center;gap:8px;margin:0 auto 24px;font-size:13px;color:var(--text-tertiary);position:relative;z-index:1}
.odqa-trust .trust-num{font-weight:800;color:var(--brand);font-size:16px}

/* ── Features ── */
.odqa-features{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;max-width:720px;margin:0 auto;position:relative;z-index:1;padding-bottom:28px}
.odqa-feat{background:var(--surface-0);border-radius:var(--radius-lg);padding:18px;text-align:center;box-shadow:var(--shadow-xs);transition:var(--transition)}
.odqa-feat:hover{transform:translateY(-2px);box-shadow:var(--shadow-sm)}
.odqa-feat-icon{font-size:24px;margin-bottom:8px}
.odqa-feat h4{font-size:13px;font-weight:700;margin-bottom:4px}
.odqa-feat p{font-size:11px;color:var(--text-tertiary);margin:0;line-height:1.4}

/* ── FAQ ── */
.odqa-faq{max-width:720px;margin:0 auto 28px;position:relative;z-index:1}
.odqa-faq-item{background:var(--surface-0);border-radius:var(--radius-lg);margin-bottom:8px;overflow:hidden;border:1px solid var(--border-light);transition:var(--transition)}
.odqa-faq-q{display:flex;align-items:center;gap:12px;padding:14px 18px;cursor:pointer;font-size:14px;font-weight:600;color:var(--text-primary)}
.odqa-faq-q:hover{background:var(--surface-1)}
.odqa-faq-q .faq-chevron{margin-left:auto;font-size:14px;color:var(--text-tertiary);transition:transform 0.3s}
.odqa-faq-a{display:none;padding:0 18px 14px 42px;font-size:13px;color:var(--text-secondary);line-height:1.7}
.odqa-faq-item.open .odqa-faq-a{display:block}.odqa-faq-item.open .faq-chevron{transform:rotate(180deg)}

/* ── Footer text ── */
.odqa-hero-footer{margin-top:28px;padding-top:20px;border-top:1px solid rgba(0,0,0,0.06);font-size:11px;color:var(--text-tertiary);line-height:1.5;position:relative;z-index:1}

/* ── Generic card ── */
.odqa-card{background:var(--surface-0);border-radius:var(--radius-xl);padding:24px;margin-bottom:16px;box-shadow:var(--shadow-sm);border:1px solid var(--border-light);transition:var(--transition)}
.odqa-card:hover{box-shadow:var(--shadow-md)}
.odqa-card-header{display:flex;align-items:center;gap:12px;margin-bottom:16px}
.odqa-card-badge{width:34px;height:34px;border-radius:10px;background:var(--brand);color:white;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:14px;flex-shrink:0}
.odqa-card-title{font-size:16px;font-weight:700}
.odqa-card-subtitle{font-size:12px;color:var(--text-secondary);margin-top:2px}
.odqa-step-header{margin-bottom:24px}
.odqa-step-header h2{font-size:24px;font-weight:800;letter-spacing:-0.5px;margin-bottom:6px}
.odqa-step-header p{font-size:14px;color:var(--text-secondary);line-height:1.6;margin:0}

/* ── Buttons ── */
.btn-odqa{display:inline-flex;align-items:center;gap:8px;padding:10px 20px;border-radius:var(--radius-md);font-size:14px;font-weight:600;border:none;cursor:pointer;transition:var(--transition);text-decoration:none}
.btn-odqa-primary{background:var(--brand);color:white}.btn-odqa-primary:hover{background:var(--brand-hover);box-shadow:0 4px 12px rgba(8,102,255,0.3);transform:translateY(-1px)}
.btn-odqa-secondary{background:var(--surface-1);color:var(--text-primary);border:1px solid var(--border)}.btn-odqa-secondary:hover{background:var(--surface-2)}
.btn-odqa-success{background:var(--success);color:white}.btn-odqa-success:hover{background:#009060}
.btn-odqa-danger{background:var(--danger);color:white}.btn-odqa-danger:hover{background:#E0282E}
.btn-odqa-ghost{background:transparent;color:var(--brand);padding:10px 16px}.btn-odqa-ghost:hover{background:var(--brand-light)}
.btn-group-odqa{display:flex;gap:8px;flex-wrap:wrap;align-items:center}

/* ── Metrics ── */
.odqa-metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:20px}
.odqa-metric{background:var(--surface-0);border-radius:var(--radius-lg);padding:20px;text-align:center;box-shadow:var(--shadow-sm);border:1px solid var(--border-light);position:relative;overflow:hidden}
.odqa-metric::before{content:'';position:absolute;top:0;left:0;right:0;height:4px}
.odqa-metric.m-checks::before{background:var(--brand)}.odqa-metric.m-issues::before{background:var(--warning)}.odqa-metric.m-affected::before{background:var(--danger)}.odqa-metric.m-score::before{background:var(--success)}
.odqa-metric .metric-value{font-size:32px;font-weight:900;letter-spacing:-1px;margin-bottom:4px}
.odqa-metric.m-checks .metric-value{color:var(--brand)}.odqa-metric.m-issues .metric-value{color:var(--warning)}.odqa-metric.m-affected .metric-value{color:var(--danger)}.odqa-metric.m-score .metric-value{color:var(--success)}
.odqa-metric .metric-label{font-size:11px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;color:var(--text-tertiary)}

/* ── Interpretation ── */
.odqa-interp{border-radius:var(--radius-lg);padding:20px 24px;margin-bottom:16px;display:flex;align-items:flex-start;gap:14px;border:1px solid}
.odqa-interp.level-ok{background:var(--success-light);border-color:#A7F3D0}.odqa-interp.level-lo{background:var(--brand-light);border-color:#BFDBFE}.odqa-interp.level-md{background:var(--warning-light);border-color:#FDE68A}.odqa-interp.level-hi{background:var(--danger-light);border-color:#FECACA}.odqa-interp.level-cr{background:var(--critical-light);border-color:#FECDD3}
.odqa-interp-icon{width:40px;height:40px;border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:20px;flex-shrink:0}
.level-ok .odqa-interp-icon{background:rgba(0,168,107,0.15);color:var(--success)}.level-lo .odqa-interp-icon{background:rgba(8,102,255,0.12);color:var(--brand)}.level-md .odqa-interp-icon{background:rgba(245,166,35,0.15);color:var(--warning)}.level-hi .odqa-interp-icon{background:rgba(250,56,62,0.15);color:var(--danger)}.level-cr .odqa-interp-icon{background:rgba(190,18,60,0.15);color:var(--critical)}
.odqa-interp-text h4{font-size:15px;font-weight:700;margin-bottom:4px}.odqa-interp-text p{font-size:13px;line-height:1.6;margin:0;color:var(--text-secondary)}

/* ── Hints ── */
.odqa-hint{display:flex;align-items:flex-start;gap:10px;padding:14px 18px;border-radius:var(--radius-md);margin-bottom:14px;font-size:13px;line-height:1.6}
.odqa-hint.info{background:var(--brand-light);color:#1E40AF}.odqa-hint.success{background:var(--success-light);color:#065F46}.odqa-hint.warning{background:var(--warning-light);color:#92400E}.odqa-hint.danger{background:var(--danger-light);color:#991B1B}
.odqa-hint-icon{font-size:16px;flex-shrink:0;margin-top:1px}

/* ── Checks ── */
.odqa-check-cat{background:var(--surface-0);border-radius:var(--radius-lg);margin-bottom:10px;overflow:hidden;border:1px solid var(--border-light)}
.odqa-check-cat-header{display:flex;align-items:center;gap:12px;padding:14px 18px;cursor:pointer;transition:background 0.15s}
.odqa-check-cat-header:hover{background:var(--surface-1)}
.odqa-check-cat-icon{width:34px;height:34px;border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:16px}
.odqa-check-cat-name{flex:1;font-size:14px;font-weight:700}
.odqa-check-cat-count{font-size:11px;font-weight:600;color:var(--text-tertiary);background:var(--surface-1);padding:3px 10px;border-radius:20px}
.check-available{opacity:1}.check-unavailable{opacity:0.45}

/* ── Builder ── */
.odqa-builder-step{display:flex;gap:14px;align-items:flex-start;margin-bottom:20px}
.odqa-builder-num{width:30px;height:30px;border-radius:50%;background:var(--brand);color:white;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:13px;flex-shrink:0;margin-top:4px}
.odqa-builder-content{flex:1;background:var(--surface-0);border-radius:var(--radius-lg);padding:18px 20px;border:1px solid var(--border-light)}
.odqa-builder-content h4{font-size:14px;font-weight:700;margin-bottom:3px}
.odqa-builder-content .hint{font-size:12px;color:var(--text-tertiary);margin-bottom:14px}

/* ── Tutorial ── */
.odqa-tut-card{background:var(--surface-0);border-radius:var(--radius-xl);margin-bottom:12px;overflow:hidden;box-shadow:var(--shadow-sm);border:1px solid var(--border-light)}
.odqa-tut-header{display:flex;align-items:center;gap:14px;padding:16px 20px;cursor:pointer;transition:var(--transition)}
.odqa-tut-header:hover{background:var(--surface-1)}
.odqa-tut-num{width:36px;height:36px;border-radius:10px;background:var(--brand);color:white;display:flex;align-items:center;justify-content:center;font-weight:800;font-size:15px;flex-shrink:0}
.odqa-tut-title{font-size:15px;font-weight:700;flex:1}
.odqa-tut-chevron{color:var(--text-tertiary);font-size:16px;transition:transform 0.3s ease}
.odqa-tut-body{display:none;padding:0 20px 20px 70px;font-size:13px;color:var(--text-secondary);line-height:1.8;white-space:pre-wrap}
.odqa-tut-card.open .odqa-tut-body{display:block}.odqa-tut-card.open .odqa-tut-chevron{transform:rotate(180deg)}

/* ── Footer nav ── */
.odqa-footer{position:fixed;bottom:0;left:0;right:0;background:var(--surface-0);border-top:1px solid var(--border-light);padding:10px 24px;display:flex;justify-content:space-between;align-items:center;z-index:1030;box-shadow:0 -2px 10px rgba(0,0,0,0.04)}
.odqa-footer .step-indicator{font-size:12px;font-weight:600;color:var(--text-tertiary)}

/* ── Forms ── */
.odqa-card .form-group label,.odqa-card .control-label{font-size:13px;font-weight:600;color:var(--text-primary);margin-bottom:6px}
.odqa-card .form-control,.odqa-card .selectize-input,.odqa-card select.form-control{border-radius:var(--radius-sm)!important;border:1.5px solid var(--border)!important;font-size:14px!important;padding:10px 14px!important;transition:var(--transition);font-family:'Inter',sans-serif!important}
.odqa-card .form-control:focus,.odqa-card .selectize-input.focus{border-color:var(--brand)!important;box-shadow:0 0 0 3px var(--brand-glow)!important}

/* ── SQL panel ── */
.odqa-sql-panel{background:#1E1E2E;border-radius:var(--radius-lg);padding:20px;margin-top:14px}
.odqa-sql-panel label{color:#CDD6F4!important}
.odqa-sql-panel .form-control{background:#313244!important;color:#CDD6F4!important;border-color:#45475A!important}
.sql-template-btns{display:flex;gap:6px;margin-bottom:10px;flex-wrap:wrap}
.sql-template-btns .btn{font-size:11px;padding:5px 12px;border-radius:20px;background:#45475A;color:#CDD6F4;border:none;font-weight:600;cursor:pointer;transition:var(--transition)}
.sql-template-btns .btn:hover{background:var(--brand);color:white}

/* ── DT ── */
.dataTables_wrapper{font-family:'Inter',sans-serif!important}
table.dataTable{border-collapse:collapse!important}
table.dataTable thead th{background:var(--surface-1)!important;font-size:12px!important;font-weight:700!important;text-transform:uppercase;letter-spacing:0.3px;border-bottom:2px solid var(--border)!important;padding:10px 12px!important}
table.dataTable tbody td{font-size:13px!important;padding:8px 12px!important;border-bottom:1px solid var(--border-light)!important}
table.dataTable tbody tr:hover{background:var(--brand-light)!important}

/* ── Charts ── */
.odqa-chart-container{background:var(--surface-0);border-radius:var(--radius-lg);padding:20px;margin-bottom:16px;border:1px solid var(--border-light)}
.odqa-chart-container h4{font-size:14px;font-weight:700;margin-bottom:14px}

/* ── Audit ── */
.odqa-audit{background:var(--surface-0);border-radius:var(--radius-lg);border:1px solid var(--border-light);padding:18px;margin-top:14px}
.odqa-audit h4{display:flex;align-items:center;gap:8px;font-size:14px;font-weight:700;margin-bottom:10px}

/* ── Source selector tabs ── */
.odqa-source-tabs{display:flex;gap:10px;margin-bottom:20px}
.odqa-source-tab{flex:1;padding:18px;border-radius:var(--radius-lg);background:var(--surface-0);border:2px solid var(--border-light);cursor:pointer;text-align:center;transition:var(--transition)}
.odqa-source-tab:hover{border-color:var(--brand);transform:translateY(-2px)}
.odqa-source-tab.active{border-color:var(--brand);background:var(--brand-light);box-shadow:0 2px 8px rgba(8,102,255,0.15)}
.odqa-source-tab .tab-icon{font-size:28px;margin-bottom:6px}
.odqa-source-tab .tab-label{font-size:13px;font-weight:700;color:var(--text-primary)}

/* ── Finish page ── */
.odqa-finish{text-align:center;padding:48px 24px;max-width:700px;margin:0 auto}
.odqa-finish h1{font-size:28px;font-weight:900;margin-bottom:12px;color:var(--success)}
.odqa-finish .recap{background:var(--surface-0);border-radius:var(--radius-xl);padding:28px;margin:20px 0;text-align:left;box-shadow:var(--shadow-sm);border:1px solid var(--border-light)}
.odqa-finish .recap h3{font-size:16px;font-weight:700;margin-bottom:12px}
.odqa-finish .recap-item{display:flex;align-items:center;gap:10px;padding:8px 0;border-bottom:1px solid var(--border-light);font-size:13px}
.odqa-finish .recap-item:last-child{border-bottom:none}
.odqa-finish .feedback-box{background:var(--brand-light);border-radius:var(--radius-lg);padding:20px;margin:16px 0;font-size:14px}
.odqa-finish .feedback-box a{color:var(--brand);font-weight:700;text-decoration:none}

/* ── Disclaimer ── */
.odqa-disclaimer-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.6);z-index:9999;display:flex;align-items:center;justify-content:center;backdrop-filter:blur(4px);animation:fadeIn 0.3s ease}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
.odqa-disclaimer-box{background:var(--surface-0);border-radius:var(--radius-2xl);padding:36px;max-width:680px;width:90%;box-shadow:var(--shadow-xl);max-height:85vh;overflow-y:auto}
.odqa-disclaimer-box h2{font-size:20px;font-weight:800;margin-bottom:14px;color:var(--brand)}
.odqa-disclaimer-box .disc-text{font-size:13px;line-height:1.8;color:var(--text-secondary);margin-bottom:20px;padding:18px;background:var(--surface-1);border-radius:var(--radius-md);border-left:4px solid var(--brand);white-space:pre-line}
.odqa-disclaimer-box .disc-cb{display:flex;align-items:flex-start;gap:12px;margin-bottom:16px;padding:14px;background:var(--success-light);border-radius:var(--radius-md);cursor:pointer}
.odqa-disclaimer-box .disc-cb input[type=checkbox]{width:18px;height:18px;margin-top:2px;flex-shrink:0;accent-color:var(--brand)}
.odqa-disclaimer-box .disc-cb label{font-size:13px;font-weight:600;cursor:pointer}
.odqa-disclaimer-box .disc-btn{width:100%;padding:12px;border:none;border-radius:var(--radius-md);font-size:15px;font-weight:700;cursor:pointer;transition:var(--transition)}
.odqa-disclaimer-box .disc-btn.enabled{background:var(--brand);color:white}
.odqa-disclaimer-box .disc-btn.enabled:hover{background:var(--brand-hover)}
.odqa-disclaimer-box .disc-btn.disabled{background:var(--surface-2);color:var(--text-tertiary);cursor:not-allowed}

/* ── Quick nav ── */
.odqa-quick-nav{display:flex;gap:6px;align-items:center;margin-bottom:16px;padding:10px 14px;background:var(--surface-0);border-radius:var(--radius-md);border:1px solid var(--border-light)}
.odqa-quick-nav .qn-btn{display:inline-flex;align-items:center;gap:5px;padding:5px 12px;border-radius:20px;font-size:11px;font-weight:600;border:1px solid var(--border);background:var(--surface-1);color:var(--text-secondary);cursor:pointer;transition:var(--transition)}
.odqa-quick-nav .qn-btn:hover{background:var(--brand-light);color:var(--brand);border-color:var(--brand)}
.odqa-quick-nav .qn-btn.danger:hover{background:var(--danger-light);color:var(--danger)}
.odqa-quick-nav .qn-sep{width:1px;height:18px;background:var(--border);margin:0 3px}

/* ── Diff ── */
.diff-changed{background:#D1FAE5!important;color:#065F46!important;font-weight:600}
.diff-deleted{background:#FEE2E2!important;color:#991B1B!important;text-decoration:line-through}
.odqa-compare{display:grid;grid-template-columns:1fr 1fr;gap:14px}
.odqa-score-info{font-size:11px;color:var(--text-tertiary);text-align:center;margin-top:4px;font-style:italic}

/* ── AI Assistant ── */
.ai-assist-card{background:linear-gradient(135deg,#EBF5FF,#F5F0FF);border:2px solid var(--brand);border-radius:var(--radius-xl);padding:20px;margin-bottom:16px}
.ai-assist-card h4{color:var(--brand);font-weight:800;margin-bottom:8px}
.ai-suggestion{background:var(--surface-0);border-radius:var(--radius-md);padding:12px 16px;margin:8px 0;border-left:4px solid var(--brand);font-size:13px}
.ai-suggestion.anomaly-high{border-left-color:var(--danger);background:var(--danger-light)}
.ai-suggestion.anomaly-medium{border-left-color:var(--warning);background:var(--warning-light)}
.ai-suggestion.anomaly-low{border-left-color:var(--success);background:var(--success-light)}

/* ── Landing page ── */
# Removed

/* ── Who box ── */
.odqa-who{max-width:720px;margin:0 auto 24px;padding:22px 28px;background:var(--surface-0);border-radius:var(--radius-xl);box-shadow:var(--shadow-sm);text-align:center;position:relative;z-index:1;border:1px solid var(--border-light)}
.odqa-who h3{font-size:16px;font-weight:800;margin-bottom:8px;letter-spacing:-0.2px;color:var(--text-primary)}
.odqa-who p{font-size:13.5px;color:var(--text-secondary);line-height:1.7;margin:0;max-width:620px;margin-left:auto;margin-right:auto}

@media(max-width:768px){.odqa-action-cards{grid-template-columns:1fr}.odqa-features{grid-template-columns:repeat(2,1fr)}.odqa-metrics{grid-template-columns:repeat(2,1fr)}.odqa-topbar-nav{display:none}.odqa-hero h1{font-size:30px}.odqa-compare{grid-template-columns:1fr}.odqa-workflow{flex-wrap:wrap}}
body.dark-mode{--surface-0:#1E1E2E;--surface-1:#181825;--surface-2:#313244;--border:#45475A;--border-light:#313244;--text-primary:#CDD6F4;--text-secondary:#A6ADC8;--text-tertiary:#6C7086;--brand-light:rgba(8,102,255,0.15);--success-light:rgba(0,168,107,0.12);--warning-light:rgba(245,166,35,0.12);--danger-light:rgba(250,56,62,0.12);--critical-light:rgba(190,18,60,0.12)}
body.dark-mode .odqa-hero{background:linear-gradient(135deg,#1a1a2e 0%,#16213e 50%,#1a1a2e 100%)}
"

# ── Section 10: UI Definition ────────────────────────────────────────────────

ui <- bs4DashPage(
  dark = NULL,
  header = bs4DashNavbar(disable = TRUE),
  sidebar = bs4DashSidebar(disable = TRUE),
  footer = bs4DashFooter(left = "", right = ""),
  body = bs4DashBody(
    useShinyjs(), useWaiter(),
    tags$head(tags$style(HTML(APP_CSS)), tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")),
    
    # ── Disclaimer Modal ──
    div(id = "disclaimer_overlay", class = "odqa-disclaimer-overlay",
        div(class = "odqa-disclaimer-box", uiOutput("disclaimer_ui"))),
    
    # ── Landing Page (optional user info) ──
    # mail entry removed
    
    # ── Top Navigation Bar ──
    div(class = "odqa-topbar",
        div(class = "odqa-topbar-brand", onclick = "Shiny.setInputValue('nav_home',Math.random())",
            div(class = "brand-icon", "DQ"), span("Open DQA")),
        div(class = "odqa-topbar-nav", id = "topnav",
            tags$button(class = "odqa-nav-pill active", id = "pill_0", onclick = "Shiny.setInputValue('nav_to',0,{priority:'event'})", "\u2302"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_1", onclick = "Shiny.setInputValue('nav_to',1,{priority:'event'})", "1"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_2", onclick = "Shiny.setInputValue('nav_to',2,{priority:'event'})", "2"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_3", onclick = "Shiny.setInputValue('nav_to',3,{priority:'event'})", "3"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_4", onclick = "Shiny.setInputValue('nav_to',4,{priority:'event'})", "4"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_5", onclick = "Shiny.setInputValue('nav_to',5,{priority:'event'})", "5"),
            tags$button(class = "odqa-nav-pill disabled", id = "pill_6", onclick = "Shiny.setInputValue('nav_to',6,{priority:'event'})", "6")),
        div(class = "odqa-topbar-actions",
            selectInput("lang", "", choices = c("EN" = "en", "DE" = "de", "FR" = "fr"), selected = "en", width = "80px"))),
    
    # ══════════════════════════════════════════════════════════════════════════
    # STEP 0: Welcome
    # ══════════════════════════════════════════════════════════════════════════
    div(class = "odqa-step active", id = "step0",
        div(class = "odqa-hero",
            div(class = "odqa-hero-content",
                uiOutput("hero_title"),
                div(class = "odqa-action-cards",
                    div(class = "odqa-action-card tutorial", onclick = "Shiny.setInputValue('go_tutorial',Math.random(),{priority:'event'})",
                        div(class = "card-icon", "\U0001F393"), uiOutput("card_tutorial"), span(class = "card-arrow", "\u2192")),
                    div(class = "odqa-action-card start", onclick = "Shiny.setInputValue('nav_to',1,{priority:'event'})",
                        div(class = "card-icon", "\U0001F680"), uiOutput("card_start"), span(class = "card-arrow", "\u2192"))),
                uiOutput("hero_workflow"),
                uiOutput("hero_who"),
                uiOutput("hero_features"),
                uiOutput("hero_faq"),
                # Footer with license, copyright, last update
                div(class = "odqa-hero-footer",
                    uiOutput("hero_footer"))))),
    
    # ══════════════════════════════════════════════════════════════════════════
    # STEP T: Tutorial
    # ══════════════════════════════════════════════════════════════════════════
    div(class = "odqa-step", id = "stepT",
        div(class = "odqa-container",
            div(class = "odqa-step-header", uiOutput("tut_header")),
            uiOutput("tut_cards"),
            div(class = "btn-group-odqa", style = "margin-top:20px;",
                tags$button(class = "btn-odqa btn-odqa-secondary", onclick = "Shiny.setInputValue('nav_to',0,{priority:'event'})", "\u2190 Back"),
                tags$button(class = "btn-odqa btn-odqa-primary", onclick = "Shiny.setInputValue('nav_to',1,{priority:'event'})", "Begin Assessment Workflow \u2192")))),
    
    # ══════════════════════════════════════════════════════════════════════════
    # STEP 1: Load Data
    # ══════════════════════════════════════════════════════════════════════════
    div(class = "odqa-step", id = "step1",
        div(class = "odqa-container",
            uiOutput("quick_nav_1"),
            div(class = "odqa-step-header", uiOutput("s1_header")),
            div(class = "odqa-hint info", span(class = "odqa-hint-icon", "\U0001F4A1"), uiOutput("s1_source_hint")),
            # Source selector tabs
            div(class = "odqa-source-tabs",
                div(class = "odqa-source-tab active", id = "src_local", onclick = "Shiny.setInputValue('src_tab','local',{priority:'event'});document.querySelectorAll('.odqa-source-tab').forEach(e=>e.classList.remove('active'));this.classList.add('active');",
                    div(class = "tab-icon", "\U0001F4C1"), div(class = "tab-label", "Local File")),
                div(class = "odqa-source-tab", id = "src_db", onclick = "Shiny.setInputValue('src_tab','db',{priority:'event'});document.querySelectorAll('.odqa-source-tab').forEach(e=>e.classList.remove('active'));this.classList.add('active');",
                    div(class = "tab-icon", "\U0001F5C4"), div(class = "tab-label", "SQL Database")),
                div(class = "odqa-source-tab", id = "src_fhir", onclick = "Shiny.setInputValue('src_tab','fhir',{priority:'event'});document.querySelectorAll('.odqa-source-tab').forEach(e=>e.classList.remove('active'));this.classList.add('active');",
                    div(class = "tab-icon", "\U0001F525"), div(class = "tab-label", "FHIR Server"))),
            # Local file panel
            div(id = "panel_local",
                div(class = "odqa-card",
                    div(class = "odqa-card-header", div(class = "odqa-card-badge", "1"), div(div(class = "odqa-card-title", "Upload File"), div(class = "odqa-card-subtitle", "CSV, Excel, JSON, or FHIR Bundle"))),
                    fluidRow(
                      column(4, selectInput("file_type", "Format", c("CSV/TXT", "Excel", "JSON", "FHIR Bundle"), width = "100%")),
                      column(8, fileInput("file_csv", "", accept = c(".csv", ".txt", ".tsv", ".xlsx", ".xls", ".json"), width = "100%"))),
                    conditionalPanel("input.file_type=='CSV/TXT'",
                                     fluidRow(column(4, selectInput("csv_sep", "Separator", c("," = ",", ";" = ";", "Tab" = "\t"), width = "100%")),
                                              column(4, checkboxInput("csv_header", "Header row", TRUE)))),
                    conditionalPanel("input.file_type=='Excel'", numericInput("xls_sheet", "Sheet", 1, min = 1, width = "120px")),
                    div(class = "btn-group-odqa", actionButton("btn_load", "", class = "btn-odqa btn-odqa-primary", icon = icon("upload"))))),
            # SQL Database panel
            div(id = "panel_db", style = "display:none;",
                div(class = "odqa-card",
                    div(class = "odqa-card-header", div(class = "odqa-card-badge", "\U0001F5C4"), div(div(class = "odqa-card-title", "SQL Database"), div(class = "odqa-card-subtitle", "PostgreSQL or Microsoft SQL Server"))),
                    div(class = "odqa-sql-panel",
                        fluidRow(
                          column(3, selectInput("sql_type", "Type", c("PostgreSQL", "Microsoft SQL"), width = "100%")),
                          column(3, textInput("sql_host", "Host", "localhost")),
                          column(2, numericInput("sql_port", "Port", 5432, min = 1)),
                          column(2, textInput("sql_db", "Database", "")),
                          column(1, textInput("sql_user", "User", "")),
                          column(1, passwordInput("sql_pw", "Pwd", ""))),
                        div(class = "btn-group-odqa", style = "margin-bottom:10px;",
                            actionButton("btn_sql_test", "Test", class = "btn btn-outline-info btn-sm")),
                        div(class = "sql-template-btns",
                            actionButton("sql_tpl_basic", "Basic SELECT", class = "btn"),
                            actionButton("sql_tpl_i2b2", "i2b2", class = "btn"),
                            actionButton("sql_tpl_omop", "OMOP CDM", class = "btn")),
                        textAreaInput("sql_query", "SQL Query", "SELECT * FROM my_table LIMIT 100;", rows = 5, width = "100%"),
                        actionButton("btn_sql_run", "Run Query", class = "btn-odqa btn-odqa-primary", icon = icon("play"))))),
            # FHIR Server panel
            div(id = "panel_fhir", style = "display:none;",
                div(class = "odqa-card",
                    div(class = "odqa-card-header", div(class = "odqa-card-badge", "\U0001F525"), div(div(class = "odqa-card-title", "FHIR Server Connection"), div(class = "odqa-card-subtitle", "Connect to an HL7 FHIR R4 server"))),
                    div(class = "odqa-hint info", span(class = "odqa-hint-icon", "\u2139\uFE0F"), span("Enter a FHIR server base URL and construct your query. Demo: https://hapi.fhir.org/baseR4")),
                    fluidRow(
                      column(6, textInput("fhir_url", "Base URL", "https://hapi.fhir.org/baseR4", width = "100%")),
                      column(6, textInput("fhir_query", "Resource Query", "Patient?_count=50", width = "100%"))),
                    div(class = "btn-group-odqa",
                        actionButton("btn_fhir_test", "Test Connection", class = "btn-odqa btn-odqa-secondary", icon = icon("plug")),
                        actionButton("btn_fhir_run", "Fetch Data", class = "btn-odqa btn-odqa-primary", icon = icon("download"))))),
            # Preview
            div(class = "odqa-card",
                div(class = "odqa-card-header", div(class = "odqa-card-badge", "\u2699"), div(class = "odqa-card-title", uiOutput("s1_preview_title", inline = TRUE))),
                DTOutput("dt_preview"),
                uiOutput("s1_perf_display")))),
    
    # ══════════════════════════════════════════════════════════════════════════
    # STEP 2: Map Columns
    # ══════════════════════════════════════════════════════════════════════════
    div(class = "odqa-step", id = "step2",
        div(class = "odqa-container",
            uiOutput("quick_nav_2"),
            div(class = "odqa-step-header", uiOutput("s2_header")),
            div(class = "odqa-card", uiOutput("mapping_ui")),
            div(class = "odqa-card",
                div(class = "odqa-card-header", div(class = "odqa-card-badge", "\u2640\u2642"), div(class = "odqa-card-title", uiOutput("s2_gender_title", inline = TRUE))),
                div(class = "odqa-hint info", span(class = "odqa-hint-icon", "\u2139\uFE0F"), uiOutput("s2_gender_explain")),
                fluidRow(
                  column(6, textInput("gmap_m", "male values", "m, male, M, 1, Mann", width = "100%")),
                  column(6, textInput("gmap_f", "female values", "f, female, F, 2, Frau", width = "100%")))),
            div(class = "btn-group-odqa", actionButton("btn_map_save", "", class = "btn-odqa btn-odqa-primary", icon = icon("check"))))),
    
    # ══════════════════════════════════════════════════════════════════════════
    # STEP 3: Built-in Checks
    # ══════════════════════════════════════════════════════════════════════════
    div(class = "odqa-step", id = "step3",
        div(class = "odqa-container-wide",
            uiOutput("quick_nav_3"),
            div(class = "odqa-step-header", uiOutput("s3_header")),
            div(class = "odqa-hint info", span(class = "odqa-hint-icon", "\U0001F4A1"), uiOutput("s3_hint")),
            div(class = "btn-group-odqa", style = "margin-bottom:16px;",
                actionButton("btn_sel_all", "", class = "btn-odqa btn-odqa-secondary", icon = icon("check-double")),
                actionButton("btn_desel", "", class = "btn-odqa btn-odqa-ghost", icon = icon("xmark"))),
            uiOutput("check_categories"))),
    
    # ══════════════════════════════════════════════════════════════════════════
    # STEP 4: Custom Check Builder
    # ══════════════════════════════════════════════════════════════════════════
    div(class = "odqa-step", id = "step4",
        div(class = "odqa-container",
            uiOutput("quick_nav_4"),
            div(class = "odqa-step-header", uiOutput("s4_header")),
            div(class = "odqa-hint info", span(class = "odqa-hint-icon", "\U0001F9E9"), uiOutput("s4_hint")),
            
            #  Assistance (moved: directly before sub-step A)
            div(class = "ai-assist-card",
                div(class = "odqa-card-header",
                    div(class = "odqa-card-title-wrap",
                        div(class = "odqa-card-title", uiOutput("ai_assist_title_ui", inline = TRUE)),
                        div(class = "odqa-card-subtitle", uiOutput("ai_checks_hint_ui", inline = TRUE)))),
                div(class = "btn-group-odqa",
                    actionButton("ai_suggest_checks", "Generate  Suggestions",
                                 class = "btn-odqa btn-odqa-primary", icon = icon("wand-magic-sparkles")),
                    actionButton("ai_clear_suggestions", "Clear",
                                 class = "btn-odqa btn-odqa-ghost", icon = icon("trash-can"))),
                uiOutput("ai_suggestions_ui")),
            
            # Step A: Conditions
            div(class = "odqa-builder-step", div(class = "odqa-builder-num", "A"),
                div(class = "odqa-builder-content",
                    h4(uiOutput("s4a_title", inline = TRUE)),
                    div(class = "hint", uiOutput("s4a_hint", inline = TRUE)),
                    fluidRow(
                      column(3, selectInput("cb_comp_type", "Comparison Type",
                                            c("Column vs. Value" = "val", "Column vs. Column" = "col"), width = "100%")),
                      column(3, uiOutput("cb_col_ui"))),
                    fluidRow(
                      column(2, selectInput("cb_op", "Operator",
                                            c("==","!=",">",">=","<","<=","contains","not_contains",
                                              "starts_with","ends_with","is.na","is_not.na",
                                              "BETWEEN","NOT BETWEEN","IN","NOT IN","REGEXP"), width = "100%")),
                      column(3, uiOutput("cb_val_or_col_ui")),
                      column(2, selectInput("cb_logic", "Logic", c("(end)","AND","OR"), width = "100%")),
                      column(2, actionButton("cb_add", "+ Add",
                                             class = "btn-odqa btn-odqa-primary", style = "margin-top:25px;width:100%;"))),
                    DTOutput("dt_conditions"),
                    div(style = "margin-top:8px;",
                        actionButton("cb_clear", "Clear Conditions",
                                     class = "btn-odqa btn-odqa-ghost", icon = icon("eraser"))))),
            
            # Step B: Generate
            div(class = "odqa-builder-step", div(class = "odqa-builder-num", "B"),
                div(class = "odqa-builder-content",
                    h4(uiOutput("s4b_title", inline = TRUE)),
                    div(class = "hint", uiOutput("s4b_hint", inline = TRUE)),
                    div(class = "btn-group-odqa",
                        actionButton("cb_gen", "Generate R Query",
                                     class = "btn-odqa btn-odqa-secondary", icon = icon("code")),
                        actionButton("cb_edit_expr", "Edit Expression",
                                     class = "btn-odqa btn-odqa-ghost", icon = icon("pen-to-square"))),
                    verbatimTextOutput("cb_expr_preview"))),
            
            # Step C: Save
            div(class = "odqa-builder-step", div(class = "odqa-builder-num", "C"),
                div(class = "odqa-builder-content",
                    h4(uiOutput("s4c_title", inline = TRUE)),
                    div(class = "hint", uiOutput("s4c_hint", inline = TRUE)),
                    fluidRow(
                      column(4, textInput("cb_name", "Check Name", "", width = "100%")),
                      column(3, selectInput("cb_sev", "Severity", c("Low","Medium","High","Critical"),
                                            selected = "Medium", width = "100%")),
                      column(5, textInput("cb_desc", "Description", "", width = "100%"))),
                    actionButton("cb_save", "Save Check",
                                 class = "btn-odqa btn-odqa-success", icon = icon("floppy-disk")))),
            
            # Import / Export + Manage saved checks
            div(class = "odqa-card",
                div(class = "odqa-card-header",
                    div(class = "odqa-card-title-wrap",
                        div(class = "odqa-card-title", "Import / Export Checks (JSON)"))),
                div(class = "btn-group-odqa",
                    fileInput("json_import", "", accept = ".json", width = "300px"),
                    downloadButton("json_export", "Export JSON", class = "btn-odqa btn-odqa-secondary"),
                    actionButton("cc_load", "Load selected → Builder", class = "btn-odqa btn-odqa-ghost", icon = icon("arrow-right")),
                    actionButton("cc_edit", "Edit selected", class = "btn-odqa btn-odqa-ghost", icon = icon("pen-to-square")),
                    actionButton("cc_delete", "Remove selected", class = "btn-odqa btn-odqa-ghost", icon = icon("trash-can"))),
                DTOutput("dt_custom_checks")))),
    
    # ══════════════════════════════════════════════════════════════════════════
    # STEP 5: Results
    # ══════════════════════════════════════════════════════════════════════════
    div(class = "odqa-step", id = "step5",
        div(class = "odqa-container",
            uiOutput("quick_nav_5"),
            div(class = "odqa-step-header", uiOutput("s5_header")),
            div(class = "btn-group-odqa", style = "margin-bottom:20px;",
                actionButton("btn_run", "", class = "btn-odqa btn-odqa-primary", icon = icon("play")),
                downloadButton("dl_word", "Word Report", class = "btn-odqa btn-odqa-secondary"),
                downloadButton("dl_csv", "CSV Report", class = "btn-odqa btn-odqa-secondary")),
            uiOutput("results_metrics"),
            uiOutput("results_score_info"),
            uiOutput("results_interp"),
            div(class = "odqa-chart-container", uiOutput("chart_sev_title"), plotOutput("plot_severity", height = "240px")),
            div(class = "odqa-chart-container", uiOutput("chart_cat_title"), plotOutput("plot_category", height = "240px")),
            div(class = "odqa-card",
                div(class = "odqa-card-header",
                    div(class = "odqa-card-title-wrap",
                        div(class = "odqa-card-title", "📊 Per-check impact"),
                        div(class = "odqa-card-subtitle",
                            switch(L(),
                                   de="Wählen Sie eine Prüfung: betroffene Zeilen + Prozent + intuitive Kurzinterpretation.",
                                   fr="Choisissez une règle : lignes affectées + pourcentage + interprétation courte.",
                                   "Pick a check: affected rows + percent + short interpretation.")))),
                uiOutput("s5_check_pick_ui"),
                plotOutput("plot_check_impact", height = "260px"),
                DTOutput("dt_check_summary")
            ),
            div(class = "odqa-card", uiOutput("detail_title"), DTOutput("dt_issues")),
            uiOutput("s5_perf_display"))),
    
    # ══════════════════════════════════════════════════════════════════════════
    # STEP 6: Cleansing
    # ══════════════════════════════════════════════════════════════════════════
    div(class = "odqa-step", id = "step6",
        div(class = "odqa-container",
            uiOutput("quick_nav_6"),
            div(class = "odqa-step-header", uiOutput("s6_header")),
            # Card 1: Issue-guided
            div(class = "odqa-card",
                div(class = "odqa-card-header", div(class = "odqa-card-badge", "1"), div(div(class = "odqa-card-title", uiOutput("s6_guide_title", inline = TRUE)), div(class = "odqa-card-subtitle", uiOutput("s6_guide_sub", inline = TRUE)))),
                uiOutput("cl_issue_select"),
                div(class = "btn-group-odqa",
                    actionButton("cl_show", "Show Affected Rows", class = "btn-odqa btn-odqa-secondary", icon = icon("eye")),
                    actionButton("cl_keep_as_is", "Keep As Is", class = "btn-odqa btn-odqa-success", icon = icon("check")),
                    actionButton("cl_edit_val", "Edit Value", class = "btn-odqa btn-odqa-primary", icon = icon("pen-to-square")),
                    actionButton("cl_del_rows", "Delete These Rows", class = "btn-odqa btn-odqa-danger", icon = icon("trash")),
                    actionButton("cl_undo_del", "Undo", class = "btn-odqa btn-odqa-ghost", icon = icon("rotate-left"))),
                uiOutput("cl_edit_panel"),
                DTOutput("dt_cl_affected")),
            # Card 2: Bulk ops
            div(class = "odqa-card",
                div(class = "odqa-card-header", div(class = "odqa-card-badge", "2"), div(div(class = "odqa-card-title", uiOutput("s6_bulk_title", inline = TRUE)))),
                tags$h5("Find & Replace", style = "font-weight:700;margin-bottom:4px;"),
                fluidRow(column(3, uiOutput("cl_fr_col_ui")), column(3, textInput("cl_find", "Find", "")), column(3, textInput("cl_repl", "Replace", ""))),
                fluidRow(
                  column(2, checkboxInput("cl_fr_regex", "Regex", FALSE)),
                  column(2, checkboxInput("cl_fr_case", "Case Sensitive", FALSE)),
                  column(2, actionButton("cl_fr_preview", "Preview", class = "btn-odqa btn-odqa-ghost", icon = icon("magnifying-glass"), style = "margin-top:15px")),
                  column(2, actionButton("cl_fr_go", "Replace All", class = "btn-odqa btn-odqa-primary", icon = icon("arrows-rotate"), style = "margin-top:15px")),
                  column(2, actionButton("cl_undo_fr", "Undo", class = "btn-odqa btn-odqa-ghost", style = "margin-top:15px", icon = icon("rotate-left")))),
                uiOutput("cl_fr_preview_ui"),
                hr(),
                tags$h5(uiOutput("s6_rename_title", inline = TRUE), style = "font-weight:700;"),
                fluidRow(column(3, uiOutput("cl_rename_col_ui")), column(4, textInput("cl_new_name", "New Name", "")),
                         column(3, actionButton("cl_rename_go", "Rename", class = "btn-odqa btn-odqa-primary", style = "margin-top:25px")),
                         column(2, actionButton("cl_undo_rename", "Undo", class = "btn-odqa btn-odqa-ghost", style = "margin-top:25px", icon = icon("rotate-left")))),
                hr(),
                tags$h5(uiOutput("s6_datefix_title", inline = TRUE), style = "font-weight:700;"),
                fluidRow(column(4, uiOutput("cl_datefix_col_ui")),
                         column(4, actionButton("cl_datefix_go", "Convert to YYYY-MM-DD", class = "btn-odqa btn-odqa-primary", style = "margin-top:25px")),
                         column(4, actionButton("cl_undo_datefix", "Undo", class = "btn-odqa btn-odqa-ghost", style = "margin-top:25px", icon = icon("rotate-left")))),
                hr(),
                fluidRow(column(4, uiOutput("cl_delcol_ui")),
                         column(4, actionButton("cl_delcol", "Delete Column", class = "btn-odqa btn-odqa-danger", style = "margin-top:25px")),
                         column(4, actionButton("cl_undo", "Undo Last", class = "btn-odqa btn-odqa-ghost", style = "margin-top:25px", icon = icon("rotate-left"))))),
            # Card ML:  Cleansing Assistant
            div(class = "ai-assist-card",
                div(class = "odqa-card-header", div(class = "odqa-card-badge", "\U0001F916"), div(div(class = "odqa-card-title", uiOutput("ai_cleanse_title_ui", inline = TRUE)), div(class = "odqa-card-subtitle", uiOutput("ai_cleanse_hint_ui", inline = TRUE)))),
                fluidRow(column(4, uiOutput("ai_cleanse_col_ui")),
                         column(4, actionButton("ai_run_cleanse", "Detect Anomalies", class = "btn-odqa btn-odqa-primary", icon = icon("magnifying-glass-chart"), style = "margin-top:25px"))),
                uiOutput("ai_cleanse_results_ui")),
            # Card 3: Manual edit
            div(class = "odqa-card",
                div(class = "odqa-card-header", div(class = "odqa-card-badge", "3"), div(div(class = "odqa-card-title", uiOutput("s6_manual_title", inline = TRUE)))),
                div(class = "odqa-hint info", span(class = "odqa-hint-icon", "\U0001F4DD"),
                    uiOutput("s6_manual_hint")),
                DTOutput("dt_cl_edit")),
            # Card 4: Audit
            div(class = "odqa-audit",
                h4("\U0001F4CB", uiOutput("s6_log_title", inline = TRUE)),
                DTOutput("dt_cl_log"),
                div(class = "btn-group-odqa", style = "margin-top:10px;",
                    downloadButton("dl_cl_data", "Download Cleaned Data", class = "btn-odqa btn-odqa-success"),
                    downloadButton("dl_cl_log_word", "Change Log (Word)", class = "btn-odqa btn-odqa-secondary"),
                    downloadButton("dl_cl_log_csv", "Change Log (CSV)", class = "btn-odqa btn-odqa-secondary"))),
            # Card 5: Compare
            div(class = "odqa-card", style = "margin-top:16px;",
                div(class = "odqa-card-header", div(class = "odqa-card-badge", "\u2194"), div(class = "odqa-card-title", uiOutput("s6_compare_title", inline = TRUE))),
                actionButton("cl_gen_compare", "Generate Comparison", class = "btn-odqa btn-odqa-primary", icon = icon("code-compare")),
                div(class = "odqa-compare", div(uiOutput("dt_cl_orig_diff")), div(uiOutput("dt_cl_clean_diff")))),
            # Finish button
            div(style = "margin-top:24px;text-align:center;",
                actionButton("btn_finish", "", class = "btn-odqa btn-odqa-success", icon = icon("flag-checkered"), style = "font-size:16px;padding:14px 32px;")))),
    
    # ══════════════════════════════════════════════════════════════════════════
    # STEP F: Finish
    # ══════════════════════════════════════════════════════════════════════════
    div(class = "odqa-step", id = "stepF",
        div(class = "odqa-finish",
            h1("\u2705 ", uiOutput("finish_title_ui", inline = TRUE)),
            uiOutput("finish_recap_ui"),
            # ── Download All Reports & Files Card ──
            div(class = "odqa-card", style = "margin-top:20px;padding:20px;border:1px solid #e2e8f0;border-radius:12px;background:#f8fafc;",
                div(class = "odqa-card-title", style = "font-size:16px;font-weight:700;margin-bottom:14px;",
                    icon("download"), " Download All Reports & Files"),
                div(style = "display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px;",
                    downloadButton("dl_final_word", "DQ Assessment Report (.docx)",
                                   class = "btn-odqa btn-odqa-secondary", style = "width:100%;text-align:left;"),
                    downloadButton("dl_final_csv", "Issues Register (.csv)",
                                   class = "btn-odqa btn-odqa-secondary", style = "width:100%;text-align:left;"),
                    downloadButton("dl_final_cl_word", "Change Log Report (.docx)",
                                   class = "btn-odqa btn-odqa-secondary", style = "width:100%;text-align:left;"),
                    downloadButton("dl_final_cl_csv", "Change Log (.csv)",
                                   class = "btn-odqa btn-odqa-secondary", style = "width:100%;text-align:left;"),
                    downloadButton("dl_final_cleaned", "Cleaned Dataset (.csv)",
                                   class = "btn-odqa btn-odqa-secondary", style = "width:100%;text-align:left;"))),
            div(class = "feedback-box",
                uiOutput("finish_feedback_ui"),
                tags$a(href = "mailto:gaetankamdje.wabo@medma.uni-heidelberg.de", "gaetankamdje.wabo@medma.uni-heidelberg.de")),
            div(style = "margin-top:24px;",
                actionButton("btn_new_analysis", "", class = "btn-odqa btn-odqa-primary", icon = icon("rotate"), style = "font-size:16px;padding:14px 32px;")))),
    
    # Footer Navigation
    div(class = "odqa-footer",
        div(class = "step-indicator", uiOutput("footer_indicator", inline = TRUE)),
        div(class = "btn-group-odqa",
            actionButton("btn_prev", "", class = "btn-odqa btn-odqa-secondary", icon = icon("arrow-left")),
            actionButton("btn_next_f", "", class = "btn-odqa btn-odqa-primary", icon = icon("arrow-right")))),
    
    # JavaScript
    tags$script(HTML("
     Shiny.addCustomMessageHandler('goto_step',function(s){document.querySelectorAll('.odqa-step').forEach(el=>el.classList.remove('active'));var m={0:'step0',1:'step1',2:'step2',3:'step3',4:'step4',5:'step5',6:'step6','T':'stepT','F':'stepF'};var t=document.getElementById(m[s]);if(t)t.classList.add('active');document.querySelectorAll('.odqa-nav-pill').forEach(p=>p.classList.remove('active'));var p=document.getElementById('pill_'+s);if(p)p.classList.add('active');window.scrollTo({top:0,behavior:'smooth'});});
     Shiny.addCustomMessageHandler('enable_pills',function(max){for(var i=0;i<=6;i++){var p=document.getElementById('pill_'+i);if(p){if(i<=max)p.classList.remove('disabled');else p.classList.add('disabled');}}});
     Shiny.addCustomMessageHandler('toggle_dark',function(d){document.body.classList.toggle('dark-mode',d);});
     Shiny.addCustomMessageHandler('hide_disclaimer',function(x){var el=document.getElementById('disclaimer_overlay');if(el)el.style.display='none';});
     Shiny.addCustomMessageHandler('show_panel',function(p){['panel_local','panel_db','panel_fhir'].forEach(function(id){document.getElementById(id).style.display='none';});var el=document.getElementById('panel_'+p);if(el)el.style.display='block';});
     document.addEventListener('click',function(e){var h=e.target.closest('.odqa-tut-header');if(h)h.closest('.odqa-tut-card').classList.toggle('open');var fq=e.target.closest('.odqa-faq-q');if(fq)fq.closest('.odqa-faq-item').classList.toggle('open');});
   "))
  )
)

# ── Section 11: Server Logic ─────────────────────────────────────────────────

server <- function(input, output, session) {
  # Reactive state
  rv <- reactiveValues(
    ai_suggestions = list(),
    cc_edit_id = NULL,
    cl_undo_files = character(),
    step = 0, max_step = 0, dark = FALSE, disclaimer_accepted = FALSE,
    raw = NULL, mapped = NULL, mapping = list(),
    checks_df = mk_checks(), custom_checks = list(),
    conditions = data.frame(column = character(), operator = character(), value = character(), logic = character(), stringsAsFactors = FALSE),
    cb_expr = "",
    issues = NULL,
    cl_data = NULL,
    cl_log = data.frame(Timestamp = character(), Action = character(), Column = character(), Rows = character(), Old = character(), New = character(), stringsAsFactors = FALSE),
    cl_undo_stack = list(),
    compare_ready = FALSE,
    # V2.0 new state
    user_info = list(name = "", func = "", email = ""),
    perf_log = data.frame(task = character(), source = character(), rows = integer(), duration_sec = numeric(), timestamp = character(), stringsAsFactors = FALSE),
    import_time = NULL,
    check_time = NULL,
    import_time = NULL,
    check_time = NULL,
    # data fingerprint for session-aware ML invalidation
    data_fingerprint = NULL
  )
  
  L <- reactive(input$lang %||% "en")
  t <- function(k) i18n(k, L())
  
  # ── Navigation ──────────────────────────────────────────────────────────────
  go <- function(s) {
    rv$step <- s
    if (is.numeric(s) && s > rv$max_step) rv$max_step <- s
    session$sendCustomMessage("goto_step", s)
    session$sendCustomMessage("enable_pills", rv$max_step)
  }
  observeEvent(input$nav_to, go(input$nav_to))
  observeEvent(input$nav_home, go(0))
  observeEvent(input$go_tutorial, go("T"))
  observeEvent(input$btn_prev, {
    s <- rv$step
    if (identical(s, "T") || identical(s, "F")) go(0)
    else if (is.numeric(s) && s > 0) go(s - 1)
  })
  observeEvent(input$btn_next_f, {
    s <- rv$step
    if (identical(s, "T")) go(1)
    else if (is.numeric(s) && s < 6) go(s + 1)
  })
  observeEvent(input$toggle_dark, { rv$dark <- !rv$dark; session$sendCustomMessage("toggle_dark", rv$dark) })
  
  # Source tab switching
  observeEvent(input$src_tab, {
    session$sendCustomMessage("show_panel", input$src_tab)
  })
  
  # ── Disclaimer ──────────────────────────────────────────────────────────────
  output$disclaimer_ui <- renderUI({
    tagList(
      h2(t("disclaimer_title")),
      div(class = "disc-text", t("disclaimer_text")),
      div(class = "disc-cb",
          checkboxInput("disc_accept_cb", "", value = FALSE, width = "20px"),
          tags$label(`for` = "disc_accept_cb", t("disclaimer_accept"))),
      actionButton("disc_proceed_btn", t("disclaimer_proceed"), class = "disc-btn disabled")
    )
  })
  observe({
    if (isTRUE(input$disc_accept_cb))
      shinyjs::runjs("document.querySelector('.disc-btn').className='disc-btn enabled';")
    else
      shinyjs::runjs("document.querySelector('.disc-btn').className='disc-btn disabled';")
  })
  observeEvent(input$disc_proceed_btn, {
    if (isTRUE(input$disc_accept_cb)) {
      rv$disclaimer_accepted <- TRUE
      session$sendCustomMessage("hide_disclaimer", TRUE)
      #  Skip landing page — go directly to welcome
    }
  })
  
  # ── Landing Page ──────────────────────────────────────────────────────────
  # User info is no longer collected via a landing page.
  # Report metadata is auto-generated from session context.
  
  # ── ML Assistant Outputs ────────────────────────────────────────────────────
  output$ai_assist_title_ui <- renderUI(span(t("ai_assist_title")))
  output$ai_checks_hint_ui <- renderUI(span(t("ai_checks_hint")))
  output$ai_cleanse_title_ui <- renderUI(span(t("ai_cleanse_title")))
  output$ai_cleanse_hint_ui <- renderUI(span(t("ai_cleanse_hint")))
  output$ai_cleanse_col_ui <- renderUI({
    req(rv$cl_data)
    selectInput("ai_cleanse_col", switch(L(), de = "Spalte analysieren", fr = "Analyser colonne", "Analyse Column"), names(rv$cl_data), width = "100%")
  })
  
  # ── ML Check Suggestions (PATCH v2.2) ─────────────────────────────────────────
  
  
  observeEvent(input$ai_suggest_checks, {
    df0 <- rv$mapped %||% rv$raw
    req(df0)
    rv$ai_suggestions <- tryCatch(ai_suggest_checks(df0, L()), error = function(e) {
      safe_notify(paste("ML suggestion error:", e$message), "warning")
      list()
    })
  })
  
  output$ai_suggestions_ui <- renderUI({
    suggestions <- rv$ai_suggestions %||% list()
    if (length(suggestions) == 0) {
      return(div(class = "odqa-hint info",
                 span(class = "odqa-hint-icon", "\U0001F916"),
                 span(switch(L(),
                             de = "Keine Vorschläge gefunden. Laden Sie Daten (und optional Mapping), dann erneut versuchen.",
                             fr = "Aucune suggestion. Chargez les données (et éventuellement le mapping), puis réessayez.",
                             "No suggestions found. Load data (and optionally mapping), then try again."))))
    }
    
    header <- div(class = "odqa-card",
                  div(class = "odqa-card-header",
                      div(class = "odqa-card-title-wrap",
                          div(class = "odqa-card-title", "🤖  Check Suggestions"),
                          div(class = "odqa-card-subtitle",
                              switch(L(),
                                     de = "Datengetriebene Vorschläge (Missingness, Ausreißer, Zeitlogik, Codes).",
                                     fr = "Suggestions basées sur les données (valeurs manquantes, outliers, logique temporelle, codes).",
                                     "Data-driven suggestions (missingness, outliers, temporal logic, codes).")))))
    
    cards <- tagList(lapply(seq_along(suggestions), function(i) {
      s <- suggestions[[i]]
      sev_icon <- switch(s$sev, Critical = "🟥", High = "🟧", Medium = "🟨", "🟩")
      is_cross <- isTRUE(s$cross_column)
      
      expr_txt <- s$expression_raw %||% "FALSE"
      
      div(class = "odqa-card", style = "margin-top:10px;",
          div(class = "odqa-card-body",
              tags$div(style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:6px;",
                       tags$strong(style="font-size:13px;", paste0(sev_icon, " ", s$name)),
                       tags$span(style="font-size:10px;background:var(--surface-1);padding:1px 8px;border-radius:10px;font-weight:700;",
                                 paste0("[", s$sev, "]")),
                       if (is_cross) tags$span(style="font-size:10px;background:var(--surface-1);padding:1px 8px;border-radius:10px;font-weight:700;",
                                               "↔ Cross-column")
              ),
              tags$div(style="font-size:13px;margin-bottom:4px;", s$desc),
              if (!is.null(s$reason) && nzchar(s$reason))
                tags$div(style="font-size:12px;color:var(--text-tertiary);font-style:italic;margin-bottom:6px;",
                         paste0("💡 ", s$reason)),
              tags$div(style="display:flex;align-items:center;gap:8px;",
                       tags$code(style="font-size:12px;background:var(--surface-1);padding:4px 10px;border-radius:6px;flex:1;",
                                 expr_txt),
                       tags$button(
                         type="button",
                         class="btn-odqa btn-odqa-ghost btn-sm",
                         style="font-size:11px;padding:4px 12px;",
                         onclick = sprintf("Shiny.setInputValue('ai_apply_idx', %d, {priority:'event'})", i),
                         switch(L(), de="Anwenden", fr="Appliquer", "Apply")
                       )
              )
          )
      )
    }))
    
    tagList(header, cards)
  })
  
  observeEvent(input$ai_apply_idx, {
    idx <- suppressWarnings(as.integer(input$ai_apply_idx))
    if (is.na(idx)) return()
    suggestions <- rv$ai_suggestions %||% list()
    if (idx < 1 || idx > length(suggestions)) return()
    
    s <- suggestions[[idx]]
    expr <- trimws(s$expression_raw %||% "")
    if (!nzchar(expr) || identical(expr, "FALSE")) {
      safe_notify(switch(L(),
                         de = "Dieser Hinweis ist informativ und wird nicht als Check gespeichert.",
                         fr = "Cette suggestion est informative et ne sera pas enregistrée comme règle.",
                         "This suggestion is informational and won't be saved as a rule."), "warning")
      return()
    }
    
    # ── [SEC-6] Security gate for ML-suggested expressions ────────────────────
    sec_blacklist_rx <- "(system|exec|shell|pipe|download|source|\\beval\\b|\\bparse\\b|assign|\\brm\\(|file\\.|readLines|writeLines|unlink|library|require|install|Sys\\.|proc\\.time|options\\(|setwd|getwd|\\bdo\\.call\\b|environment|globalenv|baseenv|new\\.env)"
    if (grepl(sec_blacklist_rx, expr, ignore.case = TRUE, perl = TRUE)) {
      safe_notify("Blocked: expression contains forbidden patterns (security policy).", "error")
      return()
    }
    parsed <- tryCatch(rlang::parse_expr(expr), error = function(e) e)
    if (inherits(parsed, "error")) {
      safe_notify(paste("Expression invalid:", parsed$message), "error")
      return()
    }
    
    # ── V2.2: Semantic check ID generation ──────────────────────────────────
    # Encode the analysis domain + target column into the ID for traceability
    type_tag <- if (!is.null(s$op) && nzchar(s$op)) {
      gsub("[^a-zA-Z]", "", tolower(substr(s$op, 1, 12)))
    } else if (!is.null(s$name)) {
      # Extract first meaningful word from name (e.g., "Completeness" -> "compl")
      first_word <- regmatches(s$name, regexpr("[A-Za-z]+", s$name))
      if (length(first_word) > 0) tolower(substr(first_word, 1, 6)) else "ml"
    } else "ml"
    
    col_tag <- if (!is.null(s$col) && nzchar(s$col)) {
      gsub("[^a-zA-Z0-9]", "", tolower(substr(s$col, 1, 15)))
    } else "gen"
    
    base_id <- paste0("ML_", type_tag, "_", col_tag)
    # Ensure uniqueness
    existing <- vapply(rv$custom_checks, function(x) x$check_id %||% "", character(1))
    k <- 1L
    new_id <- sprintf("%s_%03d", base_id, k)
    while (new_id %in% existing) { k <- k + 1L; new_id <- sprintf("%s_%03d", base_id, k) }
    
    # ── V2.2: Rich structured description ───────────────────────────────────
    # Combine all ML insight fields into a professional, auditable description
    desc_parts <- character(0)
    if (!is.null(s$name) && nzchar(s$name))
      desc_parts <- c(desc_parts, s$name)
    if (!is.null(s$desc) && nzchar(s$desc) && !identical(s$desc, s$name))
      desc_parts <- c(desc_parts, s$desc)
    if (!is.null(s$reason) && nzchar(s$reason))
      desc_parts <- c(desc_parts, paste0("[ML Insight: ", s$reason, "]"))
    if (isTRUE(s$cross_column))
      desc_parts <- c(desc_parts, "[Cross-column analysis]")
    
    rich_desc <- paste(desc_parts, collapse = " | ")
    if (!nzchar(rich_desc)) rich_desc <- " Suggested Check"
    
    # ── V2.2: Human-readable check_name for reports and plots ────────────────
    check_name <- s$name %||% new_id
    
    new_check <- list(
      check_id       = new_id,
      check_name     = check_name,
      description    = rich_desc,
      severity       = s$sev %||% "Medium",
      expression_raw = expr,
      created        = format(Sys.time(), "%Y-%m-%d %H:%M"),
      source         = "ML-Assistant",
      target_column  = s$col %||% "",
      cross_column   = isTRUE(s$cross_column)
    )
    rv$custom_checks <- c(rv$custom_checks, list(new_check))
    
    safe_notify(paste0(switch(L(),
                              de = "✅ ML-Prüfung hinzugefügt: ",
                              fr = "✅ Vérification ML ajoutée : ",
                              "✅ ML check added: "), check_name, " [", new_id, "]"), "message")
  })  # ── END observeEvent(input$ai_apply_idx) ──
  
  # ── ML Clear Suggestions (with data fingerprint guard) ────────────────
  observeEvent(input$ai_clear_suggestions, {
    rv$ai_suggestions <- list()
    safe_notify(switch(L(),
                       de = "ML-Vorschläge gelöscht.",
                       fr = "Suggestions ML effacées.",
                       "ML suggestions cleared."), "message")
  })
  
  # Data fingerprint: structural hash of column names + types + nrow
  # Used to detect when the underlying dataset has changed
  compute_data_fingerprint <- function(df) {
    if (is.null(df) || nrow(df) == 0) return(NULL)
    col_sig <- paste(sort(names(df)), collapse = "|")
    type_sig <- paste(vapply(df, function(x) class(x)[1], character(1)), collapse = "|")
    paste0(col_sig, "##", type_sig, "##", nrow(df))
  }
  
  # Auto-invalidate ML suggestions when data fingerprint changes
  observe({
    df <- rv$mapped %||% rv$raw
    new_fp <- compute_data_fingerprint(df)
    old_fp <- isolate(rv$data_fingerprint)
    # Only act if fingerprint actually changed (not on first load or same data)
    if (!identical(new_fp, old_fp)) {
      rv$data_fingerprint <- new_fp
      if (!is.null(old_fp) && length(isolate(rv$ai_suggestions)) > 0) {
        rv$ai_suggestions <- list()
        safe_notify(switch(L(),
                           de = "Datensatz geändert — ML-Vorschläge zurückgesetzt.",
                           fr = "Jeu de données modifié — suggestions ML réinitialisées.",
                           "Dataset changed — ML suggestions reset."), "message")
      }
    }
  })
  
  
  # ──── PASTE START: Step 6 ML observer ────────────────────────────────────────
  
  observeEvent(input$ai_run_cleanse, {
    req(rv$cl_data, input$ai_cleanse_col)
    results <- tryCatch(
      ai_detect_anomalies(rv$cl_data, input$ai_cleanse_col, L()),
      error = function(e) NULL
    )
    
    output$ai_cleanse_results_ui <- renderUI({
      if (is.null(results) || length(results) == 0)
        return(div(class = "odqa-hint success",
                   span(class = "odqa-hint-icon", "\u2705"),
                   span(switch(L(),
                               de = "Keine Anomalien erkannt.",
                               fr = "Aucune anomalie d\u00e9tect\u00e9e.",
                               "No anomalies detected."))))
      
      # ── Header: detected type ────────────────────────────────────────────
      det_type <- attr(results, "detected_type") %||% "unknown"
      type_label <- switch(det_type,
                           numeric     = "\U0001F522 Numeric",
                           integer     = "\U0001F522 Integer",
                           date        = "\U0001F4C5 Date",
                           datetime    = "\U0001F4C5 Datetime",
                           categorical = "\U0001F3F7\uFE0F Categorical",
                           binary      = "\U0001F3F7\uFE0F Binary",
                           code_icd    = "\U0001F3E5 ICD Code",
                           code_ops    = "\U0001F3E5 OPS Code",
                           freetext    = "\U0001F4DD Free Text",
                           id          = "\U0001F194 Identifier",
                           mixed       = "\U0001F500 Mixed",
                           det_type)
      
      # Summary counts
      n_high   <- sum(vapply(results, function(r) (r$severity %||% "low") %in% c("high","critical"), logical(1)))
      n_medium <- sum(vapply(results, function(r) identical(r$severity, "medium"), logical(1)))
      n_low    <- sum(vapply(results, function(r) identical(r$severity, "low"), logical(1)))
      total_rows_affected <- length(unique(unlist(lapply(results, function(r) r$rows))))
      
      cards <- list(
        # Type + summary banner
        div(class = "odqa-hint info", style = "margin-bottom:8px;flex-direction:column;",
            div(style = "display:flex;align-items:center;gap:8px;font-weight:700;margin-bottom:6px;",
                span("\U0001F916"),
                span(switch(L(),
                            de = paste0("Erkannter Typ: ", type_label),
                            fr = paste0("Type d\u00e9tect\u00e9: ", type_label),
                            paste0("Detected type: ", type_label)))),
            div(style = "display:flex;gap:16px;font-size:12px;",
                if (n_high > 0) span(style = "color:var(--danger);font-weight:700;",
                                     paste0("\U0001F534 ", n_high, switch(L(), de = " kritisch", fr = " critique(s)", " critical"))),
                if (n_medium > 0) span(style = "color:var(--warning);font-weight:700;",
                                       paste0("\U0001F7E1 ", n_medium, switch(L(), de = " mittel", fr = " moyen(s)", " medium"))),
                if (n_low > 0) span(style = "color:var(--success);font-weight:700;",
                                    paste0("\U0001F7E2 ", n_low, switch(L(), de = " gering", fr = " faible(s)", " low"))),
                span(style = "color:var(--text-tertiary);",
                     paste0("| ", total_rows_affected, switch(L(),
                                                              de = " Zeilen betroffen", fr = " lignes affect\u00e9es", " rows affected")))))
      )
      
      # ── Sort results: critical/high first ────────────────────────────────
      sev_priority <- c(critical = 1, high = 2, medium = 3, low = 4)
      res_order <- order(vapply(results, function(r) {
        sev_priority[r$severity %||% "low"] %||% 5
      }, numeric(1)))
      
      for (idx in res_order) {
        res_name <- names(results)[idx]
        r <- results[[idx]]
        sev <- r$severity %||% "low"
        
        sev_class <- switch(sev,
                            high = "anomaly-high", critical = "anomaly-high",
                            medium = "anomaly-medium", "anomaly-low")
        sev_icon <- switch(sev,
                           high = "\U0001F534", critical = "\U0001F6A8",
                           medium = "\U0001F7E1", "\U0001F7E2")
        
        type_icon <- switch(r$type %||% "",
                            extreme_outlier      = "\U0001F4C8",
                            mild_outlier         = "\U0001F4CA",
                            zscore_outlier       = "\U0001F4C9",
                            impossible_value     = "\u26D4",
                            suspect_value        = "\u2753",
                            distribution         = "\U0001F4CA",
                            typo                 = "\u270D\uFE0F",
                            rare                 = "\U0001F50D",
                            casing               = "\U0001F520",
                            whitespace           = "\u2423",
                            encoding             = "\U0001F4BB",
                            missing              = "\u2753",
                            missing_representation = "\u2753",
                            format_error         = "\u274C",
                            format               = "\U0001F4DD",
                            format_inconsistency = "\u26A0\uFE0F",
                            temporal             = "\u23F0",
                            temporal_outlier     = "\u23F0",
                            duplicate            = "\U0001F503",
                            duplicate_text       = "\U0001F4CB",
                            test_data            = "\u26A0\uFE0F",
                            invalid_code         = "\u274C",
                            code_quality         = "\U0001F50D",
                            length_outlier       = "\U0001F4CF",
                            empty                = "\u26D4",
                            "\U0001F50D")
        
        # ── Build card content ─────────────────────────────────────────────
        card_parts <- list()
        
        # Title line
        card_parts <- c(card_parts, list(
          tags$div(style = "display:flex;align-items:center;gap:6px;flex-wrap:wrap;",
                   tags$strong(style = "font-size:13px;", paste0(sev_icon, " ", type_icon, " ")),
                   tags$span(style = "font-size:13px;font-weight:600;", r$suggestion %||% res_name),
                   tags$span(style = "font-size:10px;background:var(--surface-1);padding:1px 8px;border-radius:10px;font-weight:600;color:var(--text-tertiary);",
                             toupper(r$type %||% "")))
        ))
        
        # Correction suggestion
        if (!is.null(r$correction) && nzchar(r$correction)) {
          card_parts <- c(card_parts, list(
            tags$div(style = "margin-top:6px;padding:8px 12px;background:rgba(255,255,255,0.6);border-radius:8px;font-size:12px;border-left:3px solid var(--brand);",
                     tags$span(style = "font-weight:700;color:var(--brand);", "\U0001F527 "),
                     tags$span(style = "color:var(--text-secondary);", r$correction))
          ))
        }
        
        # Affected rows
        if (!is.null(r$rows) && length(r$rows) > 0) {
          n_show <- min(10, length(r$rows))
          row_text <- paste(r$rows[1:n_show], collapse = ", ")
          if (length(r$rows) > n_show) {
            row_text <- paste0(row_text, " \u2026 (+", length(r$rows) - n_show, ")")
          }
          card_parts <- c(card_parts, list(
            tags$div(style = "margin-top:4px;font-size:11px;color:var(--text-tertiary);",
                     tags$span(style = "font-weight:600;", switch(L(),
                                                                  de = "Zeilen: ", fr = "Lignes: ", "Rows: ")),
                     row_text)
          ))
        }
        
        # Sample values
        if (!is.null(r$values) && length(r$values) > 0) {
          uv <- unique(as.character(r$values))
          n_show_v <- min(6, length(uv))
          card_parts <- c(card_parts, list(
            tags$div(style = "margin-top:2px;font-size:11px;color:var(--text-tertiary);",
                     tags$span(style = "font-weight:600;", switch(L(),
                                                                  de = "Werte: ", fr = "Valeurs: ", "Values: ")),
                     tags$code(style = "font-size:11px;", paste(uv[1:n_show_v], collapse = " | ")),
                     if (length(uv) > n_show_v) paste0(" (+", length(uv) - n_show_v, ")"))
          ))
        }
        
        # Typo detail table
        if (!is.null(r$details) && identical(r$type, "typo")) {
          typo_rows <- lapply(r$details[1:min(8, length(r$details))], function(td) {
            tags$div(style = "display:flex;align-items:center;gap:8px;padding:3px 0;font-size:12px;border-bottom:1px solid var(--border-light);",
                     tags$code(style = "color:var(--danger);text-decoration:line-through;", td$rare_value),
                     tags$span("\u2192"),
                     tags$code(style = "color:var(--success);font-weight:700;", td$suggested),
                     tags$span(style = "color:var(--text-tertiary);font-size:10px;margin-left:auto;",
                               paste0(td$freq_rare, "\u00d7 vs ", td$freq_match, "\u00d7")))
          })
          card_parts <- c(card_parts, list(
            tags$div(style = "margin-top:8px;padding:8px;background:rgba(255,255,255,0.5);border-radius:8px;",
                     tags$div(style = "font-size:11px;font-weight:700;margin-bottom:4px;",
                              switch(L(), de = "Korrekturvorschl\u00e4ge:", fr = "Corrections sugg\u00e9r\u00e9es:", "Suggested corrections:")),
                     typo_rows)
          ))
        }
        
        # Case inconsistency detail
        if (!is.null(r$details) && identical(r$type, "casing")) {
          case_rows <- lapply(r$details[1:min(5, length(r$details))], function(forms) {
            tags$div(style = "font-size:12px;padding:2px 0;",
                     paste0("{", paste(forms, collapse = ", "), "}"))
          })
          card_parts <- c(card_parts, list(
            tags$div(style = "margin-top:6px;", case_rows)
          ))
        }
        
        cards <- c(cards, list(
          div(class = paste("ai-suggestion", sev_class), style = "margin:6px 0;",
              tagList(card_parts))
        ))
      }
      
      # ── Footer summary ───────────────────────────────────────────────────
      cards <- c(cards, list(
        div(style = "margin-top:12px;font-size:11px;color:var(--text-tertiary);text-align:center;font-style:italic;",
            switch(L(),
                   de = "Analyse abgeschlossen. Nutzen Sie die Werkzeuge oben, um die erkannten Probleme zu beheben.",
                   fr = "Analyse termin\u00e9e. Utilisez les outils ci-dessus pour corriger les probl\u00e8mes.",
                   "Analysis complete. Use the cleansing tools above to address detected issues."))
      ))
      
      tagList(cards)
    })
  })
  
  # ──── PASTE END: Step 6 ML observer ──────────────────────────────────────────
  
  # ── Performance Display ─────────────────────────────────────────────────────
  output$s1_perf_display <- renderUI({
    if (is.null(rv$import_time)) return(NULL)
    div(class = "odqa-hint success", span(class = "odqa-hint-icon", "\u23F1"),
        span(paste0(switch(L(), de = "Import-Dauer: ", fr = "Dur\u00e9e d'import: ", "Import duration: "),
                    round(rv$import_time, 2), "s")))
  })
  output$s5_perf_display <- renderUI({
    if (is.null(rv$check_time)) return(NULL)
    div(class = "odqa-hint success", span(class = "odqa-hint-icon", "\u23F1"),
        span(paste0(switch(L(), de = "Pr\u00fcfungs-Dauer: ", fr = "Dur\u00e9e des v\u00e9rifications: ", "Check duration: "),
                    round(rv$check_time, 2), "s")))
  })
  
  # ── Quick-Nav Toolbar ───────────────────────────────────────────────────────
  make_quick_nav <- function(step_num) {
    renderUI({
      div(class = "odqa-quick-nav",
          tags$button(class = "qn-btn", onclick = "Shiny.setInputValue('nav_to',0,{priority:'event'})", "\u2302 ", t("nav_home_btn")),
          tags$button(class = "qn-btn", onclick = "Shiny.setInputValue('go_tutorial',Math.random(),{priority:'event'})", "\U0001F393 ", t("nav_tutorial")),
          div(class = "qn-sep"),
          tags$button(class = "qn-btn danger", onclick = "Shiny.setInputValue('reset_all',Math.random(),{priority:'event'})", "\U0001F504 ", t("nav_refresh")))
    })
  }
  output$quick_nav_1 <- make_quick_nav(1); output$quick_nav_2 <- make_quick_nav(2)
  output$quick_nav_3 <- make_quick_nav(3); output$quick_nav_4 <- make_quick_nav(4)
  output$quick_nav_5 <- make_quick_nav(5); output$quick_nav_6 <- make_quick_nav(6)
  
  # ── Reset All ───────────────────────────────────────────────────────────────
  observeEvent(input$reset_all, {
    showModal(modalDialog(title = t("nav_refresh"), t("confirm_reset"),
                          footer = tagList(modalButton(t("btn_back")), actionButton("confirm_reset_btn", t("nav_refresh"), class = "btn-odqa btn-odqa-danger")), easyClose = TRUE))
  })
  observeEvent(input$confirm_reset_btn, {
    removeModal()
    rv$raw <- NULL; rv$mapped <- NULL; rv$mapping <- list()
    rv$checks_df <- mk_checks(); rv$custom_checks <- list()
    rv$ai_suggestions <- list(); rv$data_fingerprint <- NULL
    rv$conditions <- rv$conditions[0, ]; rv$cb_expr <- ""
    rv$issues <- NULL; rv$cl_data <- NULL; rv$cl_log <- rv$cl_log[0, ]; rv$cl_undo_stack <- list()
    rv$compare_ready <- FALSE; rv$step <- 0; rv$max_step <- 0
    session$sendCustomMessage("goto_step", 0); session$sendCustomMessage("enable_pills", 0)
    safe_notify("\U0001F504 Reset complete!", "message")
  })
  
  # ── Welcome Page Outputs ────────────────────────────────────────────────────
  output$hero_title <- renderUI(tagList(
    h1(t("wel_title")),
    div(class = "subtitle", t("wel_sub")),
    div(class = "desc", t("wel_desc"))))
  output$card_tutorial <- renderUI(tagList(h3(t("wel_tut")), p(t("wel_tut_hint"))))
  output$card_start <- renderUI(tagList(h3(t("wel_start")), p(t("wel_start_hint"))))
  output$hero_workflow <- renderUI({
    steps <- list(
      list(n = "1", l = switch(L(), de = "Laden", fr = "Charger", "Load")),
      list(n = "2", l = switch(L(), de = "Zuordnen", fr = "Mapper", "Map")),
      list(n = "3", l = switch(L(), de = "Pr\u00fcfungen", fr = "V\u00e9rifier", "Check")),
      list(n = "4", l = switch(L(), de = "Eigene", fr = "Perso.", "Custom")),
      list(n = "5", l = switch(L(), de = "Ergebnisse", fr = "R\u00e9sultats", "Results")),
      list(n = "6", l = switch(L(), de = "Bereinigen", fr = "Nettoyer", "Cleanse")))
    tagList(
      h3(t("wel_workflow_title"), style = "font-size:17px;font-weight:800;margin-bottom:14px;position:relative;z-index:1;"),
      div(class = "odqa-workflow", lapply(steps, function(s) div(class = "odqa-wf-step", div(class = "odqa-wf-num", s$n), div(class = "odqa-wf-label", s$l)))))
  })
  output$hero_who <- renderUI(div(class = "odqa-who", h3(t("wel_who_title")), p(t("wel_who"))))
  output$hero_features <- renderUI({
    feats <- list(
      list(icon = "\U0001F4C2", t = t("feat_import"), d = t("feat_import_d")),
      list(icon = "\u2705", t = t("feat_checks"), d = t("feat_checks_d")),
      list(icon = "\U0001F527", t = t("feat_builder"), d = t("feat_builder_d")),
      list(icon = "\U0001F4CA", t = t("feat_report"), d = t("feat_report_d")),
      list(icon = "\U0001F9F9", t = t("feat_cleanse"), d = t("feat_cleanse_d")),
      list(icon = "\U0001F310", t = t("feat_lang"), d = t("feat_lang_d")))
    div(class = "odqa-features", lapply(feats, function(f) div(class = "odqa-feat", div(class = "odqa-feat-icon", f$icon), h4(f$t), p(f$d))))
  })
  output$hero_faq <- renderUI({
    tagList(
      h3(t("wel_faq_title"), style = "font-size:17px;font-weight:800;margin:24px auto 14px;max-width:720px;text-align:left;position:relative;z-index:1;"),
      div(class = "odqa-faq", lapply(seq_along(FAQ_DATA), function(i) {
        fq <- FAQ_DATA[[i]]
        div(class = "odqa-faq-item",
            div(class = "odqa-faq-q", span(paste0("Q", i, ". ")), span(fq$q[[L()]]), span(class = "faq-chevron", "\u25BC")),
            div(class = "odqa-faq-a", fq$a[[L()]]))
      })))
  })
  output$hero_footer <- renderUI({
    tagList(
      tags$div(style = "font-size:12px;font-weight:600;color:var(--text-secondary);margin-bottom:6px;",
               "Open DQA V0.1  |  MIT License  |  \u00a9 2026 Heidelberg University"),
      tags$div(style = "font-size:11px;",
               "Authors: Gaetan Kamdje Wabo et al."),
      tags$div(style = "font-size:11px;",
               "DBMI, Medical Faculty Mannheim, University Heidelberg"),
      tags$div(style = "font-size:10px;margin-top:4px;",
               paste0("Last update: ", format(Sys.Date(), "%B %d, %Y"))))
  })
  
  # ── Tutorial ────────────────────────────────────────────────────────────────
  output$tut_header <- renderUI(tagList(h2(t("tut_title")), p(t("tut_sub"))))
  output$tut_cards <- renderUI({
    steps <- list(
      list(n = 1, t = switch(L(), de = "Daten laden", fr = "Charger les donn\u00e9es", "Loading Your Data"),
           b = switch(L(),
                      de = paste0(
                        "\U0001F3AF ZIEL: Ihren klinischen Datensatz in Open DQA importieren.\n\n",
                        "\U0001F4C2 UNTERST\u00dcTZTE FORMATE:\n",
                        "\u2022 CSV/TXT \u2013 Komma-, Semikolon- oder Tab-getrennte Dateien (h\u00e4ufigstes Format)\n",
                        "\u2022 Excel (.xlsx/.xls) \u2013 Sie k\u00f6nnen das gew\u00fcnschte Tabellenblatt ausw\u00e4hlen\n",
                        "\u2022 JSON \u2013 Standard-Arrays, verschachtelte Objekte oder NDJSON\n",
                        "\u2022 FHIR R4 Bundle \u2013 HL7-konforme klinische Ressourcen\n",
                        "\u2022 SQL-Datenbank \u2013 Direkte Verbindung zu PostgreSQL oder Microsoft SQL Server\n",
                        "\u2022 FHIR-Server \u2013 Live-Abfrage eines FHIR-Endpunkts\n\n",
                        "\U0001F4A1 KONKRETE BEISPIELE:\n",
                        "Beispiel 1: Excel-Datei \u2192 Format 'Excel' \u2192 Browse \u2192 Tabellenblatt w\u00e4hlen \u2192 'Daten laden'\n",
                        "Beispiel 2: CSV mit Semikolon \u2192 Format 'CSV/TXT' \u2192 Separator ';' \u2192 Datei laden\n",
                        "Beispiel 3: SQL \u2192 Tab 'SQL-Datenbank' \u2192 Zugangsdaten \u2192 Testen \u2192 Abfrage ausf\u00fchren\n\n",
                        "\u26A0\uFE0F WICHTIG: Mindestens EINE Spalte mit klinischen Codes oder Datumsangaben. Daten verlassen nie Ihren Rechner."),
                      fr = paste0(
                        "\U0001F3AF OBJECTIF : Importer votre jeu de donn\u00e9es cliniques.\n\n",
                        "FORMATS : CSV/TXT, Excel, JSON, FHIR Bundle, SQL, Serveur FHIR\n\n",
                        "EXEMPLES : Excel \u2192 s\u00e9lectionnez le format \u2192 parcourez \u2192 chargez\n",
                        "CSV avec ; \u2192 changez le s\u00e9parateur \u2192 chargez\n",
                        "SQL \u2192 entrez les identifiants \u2192 testez \u2192 ex\u00e9cutez\n\n",
                        "IMPORTANT : Au minimum UNE colonne avec des codes cliniques ou des dates."),
                      paste0(
                        "\U0001F3AF GOAL: Get your clinical dataset into Open DQA for quality assessment.\n\n",
                        "\U0001F4C2 SUPPORTED FORMATS:\n",
                        "\u2022 CSV/TXT \u2013 Comma-, semicolon-, or tab-separated (most common in research)\n",
                        "\u2022 Excel (.xlsx/.xls) \u2013 Select which sheet to load\n",
                        "\u2022 JSON \u2013 Standard arrays, nested objects, or NDJSON\n",
                        "\u2022 FHIR R4 Bundle \u2013 HL7-compliant clinical resources (Patient, Encounter, Condition, Procedure)\n",
                        "\u2022 SQL Database \u2013 Direct connection to PostgreSQL or Microsoft SQL Server\n",
                        "\u2022 FHIR Server \u2013 Live query of a FHIR endpoint (e.g. HAPI FHIR)\n\n",
                        "\U0001F4A1 CONCRETE EXAMPLES:\n",
                        "Example 1: Excel from EDC system \u2192 Select 'Excel' \u2192 Browse \u2192 Pick sheet \u2192 'Load Data'\n",
                        "Example 2: CSV with semicolons (European) \u2192 Select 'CSV/TXT' \u2192 Separator ';' \u2192 Load\n",
                        "Example 3: SQL query from IT \u2192 'SQL Database' tab \u2192 Enter credentials \u2192 Test \u2192 Run Query\n\n",
                        "\u26A0\uFE0F IMPORTANT:\n",
                        "\u2022 Minimum: at least ONE column with clinical codes (ICD/OPS) or dates\n",
                        "\u2022 Your data NEVER leaves your machine (except SQL/FHIR server connections)\n",
                        "\u2022 After loading: preview of first 200 rows appears immediately"))),
      list(n = 2, t = switch(L(), de = "Spalten zuordnen", fr = "Mapper les colonnes", "Mapping Columns"),
           b = switch(L(),
                      de = paste0(
                        "\U0001F3AF ZIEL: Open DQA mitteilen, welche Spalte welcher Bedeutung entspricht.\n\n",
                        "\U0001F4CB WARUM? Jeder Datensatz hat andere Spaltennamen. 'Aufnahmedatum', 'admission_dt', 'DAT_ADM' \u2013 Open DQA muss wissen, was was ist.\n\n",
                        "\U0001F527 SO GEHT ES:\n",
                        "1. Auto-Erkennung f\u00fcllt wahrscheinliche Zuordnungen vor\n",
                        "2. 9 Standardfelder: patient_id, icd, ops, gender, admission_date, discharge_date, age, birth_date, anamnese\n",
                        "3. Pr\u00fcfen und ggf. korrigieren \u2013 nicht alle m\u00fcssen zugeordnet werden\n\n",
                        "\U0001F4A1 BEISPIEL: 'PAT_NR' \u2192 patient_id, 'DIAG_CODE' \u2192 icd, 'GESCHLECHT' \u2192 gender\n\n",
                        "\u2640\u2642 GESCHLECHT: Alle Werte f\u00fcr m\u00e4nnlich/weiblich angeben (z.B. m, male, 1, Mann)"),
                      fr = paste0(
                        "\U0001F3AF OBJECTIF : Indiquer quelles colonnes correspondent \u00e0 quels champs standard.\n\n",
                        "POURQUOI ? Chaque jeu a des noms diff\u00e9rents. Open DQA d\u00e9tecte automatiquement, v\u00e9rifiez et corrigez.\n",
                        "9 champs : patient_id, icd, ops, gender, dates, age, anamnese\n\n",
                        "GENRE : Indiquez toutes les valeurs masculin/f\u00e9minin (m, male, 1, Mann / f, female, 2, Frau)"),
                      paste0(
                        "\U0001F3AF GOAL: Tell Open DQA which columns correspond to which standard clinical fields.\n\n",
                        "\U0001F4CB WHY? Every dataset has different column names. Open DQA needs to know which is which.\n\n",
                        "\U0001F527 HOW:\n",
                        "1. Auto-detection pre-fills likely matches (e.g. 'icd_code' \u2192 icd)\n",
                        "2. 9 standard fields with dropdowns: patient_id, icd, ops, gender, admission_date, discharge_date, age, birth_date, anamnese\n",
                        "3. Review and correct. Not all fields need mapping \u2013 only those in your data.\n\n",
                        "\U0001F4A1 EXAMPLE:\n",
                        "'PAT_NR' \u2192 patient_id | 'DIAG_CODE' \u2192 icd | 'SEX' \u2192 gender | 'ADM_DATE' \u2192 admission_date\n\n",
                        "\u2640\u2642 GENDER STANDARDISATION:\n",
                        "Enter ALL values meaning 'male' (e.g. m, male, M, 1, Mann) and 'female' (e.g. f, female, F, 2, Frau).\n",
                        "WHY: Gender-specific checks need standardised values (e.g. 'pregnancy in male' check)."))),
      list(n = 3, t = switch(L(), de = "Standardpr\u00fcfungen", fr = "V\u00e9rifications int\u00e9gr\u00e9es", "Built-in Checks"),
           b = switch(L(),
                      de = paste0(
                        "\U0001F3AF ZIEL: Relevante Qualit\u00e4tspr\u00fcfungen ausw\u00e4hlen.\n\n",
                        "77 PR\u00dcFUNGEN IN 6 KATEGORIEN:\n\n",
                        "1\uFE0F\u20E3 VOLLST\u00c4NDIGKEIT (16): Fehlen relevante Informationen?\n",
                        "   Bsp: 'Aufnahme vorhanden, aber ICD-Code fehlt'\n\n",
                        "2\uFE0F\u20E3 ALTERS-PLAUSIBILIT\u00c4T (15): Passt die Diagnose zum Alter?\n",
                        "   Bsp: 'Prostatakrebs (C61) bei Alter < 15'\n\n",
                        "3\uFE0F\u20E3 GESCHLECHTS-PLAUSIBILIT\u00c4T (15): Passt die Diagnose zum Geschlecht?\n",
                        "   Bsp: 'Schwangerschaft (O-Codes) bei m\u00e4nnlichem Patient'\n\n",
                        "4\uFE0F\u20E3 ZEITLICHE KONSISTENZ (6): Stimmt die Datum-Logik?\n",
                        "   Bsp: 'Entlassung vor Aufnahme'\n\n",
                        "5\uFE0F\u20E3 DIAGNOSE-PROZEDUR (15): Passen Prozeduren zu Diagnosen?\n",
                        "   Bsp: 'Appendektomie-OPS ohne K35-ICD'\n\n",
                        "6\uFE0F\u20E3 CODE-INTEGRIT\u00c4T (10): Sind die Codes formal korrekt?\n",
                        "   Bsp: 'ICD-Code hat ung\u00fcltiges Format'\n\n",
                        "\U0001F7E2 Farbig = verf\u00fcgbar | \u26AA Grau = nicht verf\u00fcgbar\n",
                        "TIPP: 'Alle w\u00e4hlen' und dann Irrelevante abw\u00e4hlen."),
                      fr = paste0(
                        "\U0001F3AF OBJECTIF : S\u00e9lectionner les v\u00e9rifications pertinentes.\n\n",
                        "77 V\u00c9RIFICATIONS EN 6 CAT\u00c9GORIES :\n",
                        "1. Compl\u00e9tude (16) \u2013 Ex: admission sans diagnostic\n",
                        "2. Plausibilit\u00e9 \u00e2ge (15) \u2013 Ex: cancer prostate chez enfant\n",
                        "3. Plausibilit\u00e9 genre (15) \u2013 Ex: grossesse chez patient masculin\n",
                        "4. Coh\u00e9rence temporelle (6) \u2013 Ex: sortie avant admission\n",
                        "5. Diagnostic-Proc\u00e9dure (15) \u2013 Ex: appendicectomie sans K35\n",
                        "6. Int\u00e9grit\u00e9 codes (10) \u2013 Ex: format ICD invalide\n\n",
                        "\U0001F7E2 Color\u00e9 = disponible | \u26AA Gris\u00e9 = indisponible"),
                      paste0(
                        "\U0001F3AF GOAL: Select which quality checks are relevant for your dataset.\n\n",
                        "77 CHECKS IN 6 CATEGORIES:\n\n",
                        "1\uFE0F\u20E3 COMPLETENESS (16 checks): Is relevant information missing?\n",
                        "   Ex: 'Admission present but ICD missing' \u2013 patient admitted but no diagnosis coded.\n",
                        "   Ex: 'Diabetes in notes but no E10-E14 ICD' \u2013 text says diabetes, not coded.\n\n",
                        "2\uFE0F\u20E3 AGE PLAUSIBILITY (15 checks): Does the diagnosis make sense for the age?\n",
                        "   Ex: 'Prostate cancer (C61) in patient < 15' \u2013 extremely unlikely.\n",
                        "   Ex: 'Alzheimer (G30) in patient < 30' \u2013 rare, warrants review.\n\n",
                        "3\uFE0F\u20E3 GENDER PLAUSIBILITY (15 checks): Does the diagnosis match the sex?\n",
                        "   Ex: 'Pregnancy codes (O-chapter) in male' \u2013 definitely an error.\n",
                        "   Ex: 'Breast cancer (C50) in male' \u2013 rare but possible, flagged for review.\n\n",
                        "4\uFE0F\u20E3 TEMPORAL CONSISTENCY (6 checks): Is the date logic correct?\n",
                        "   Ex: 'Discharge before admission' \u2013 impossible, dates wrong.\n",
                        "   Ex: 'Admission in the future' \u2013 data entry error.\n\n",
                        "5\uFE0F\u20E3 DIAGNOSIS-PROCEDURE (15 checks): Do procedures match diagnoses?\n",
                        "   Ex: 'Appendectomy OPS without K35 ICD' \u2013 surgery without diagnosis.\n",
                        "   Ex: 'Chemotherapy OPS without cancer ICD' \u2013 chemo without cancer code.\n\n",
                        "6\uFE0F\u20E3 CODE INTEGRITY (10 checks): Are codes formally valid?\n",
                        "   Ex: 'Invalid ICD syntax' \u2013 e.g. '123.4' instead of 'A12.3'.\n",
                        "   Ex: 'Placeholder ICD (xxx, zzz)' \u2013 test data included.\n\n",
                        "\U0001F7E2 COLOURED = available | \u26AA GREYED = unavailable (map more columns to unlock)\n",
                        "TIP: Click 'Select All' first, then deselect irrelevant checks."))),
      list(n = 4, t = switch(L(), de = "Eigene Pr\u00fcfungen (Fitness-for-Purpose)", fr = "V\u00e9rifications personnalis\u00e9es (Fitness-for-Purpose)", "Custom Checks (Fitness-for-Purpose)"),
           b = switch(L(),
                      de = paste0(
                        "\U0001F3AF ZIEL: Eigene, studienspezifische Qualit\u00e4tspr\u00fcfungen erstellen.\n\n",
                        "WARUM 'FITNESS-FOR-PURPOSE'?\n",
                        "Die 77 Standardpr\u00fcfungen decken universelle Plausibilit\u00e4t ab. Ihre Studie hat eigene Anforderungen:\n",
                        "\u2022 Studie nur f\u00fcr Patienten \u00fcber 65? \u2192 age < 65 markieren\n",
                        "\u2022 Nur I-Kapitel ICD akzeptiert? \u2192 andere Codes markieren\n\n",
                        "3 SCHRITTE:\n",
                        "A. Bedingungen: Spalte vs. Wert ODER Spalte vs. Spalte (mischbar mit AND/OR)\n",
                        "B. R-Abfrage generieren und pr\u00fcfen\n",
                        "C. Speichern mit Name, Schweregrad, Beschreibung\n\n",
                        "Import/Export als JSON f\u00fcr Multi-Center-Studien."),
                      fr = paste0(
                        "\U0001F3AF OBJECTIF : Cr\u00e9er des v\u00e9rifications fitness-for-purpose.\n\n",
                        "Les 77 v\u00e9rifications couvrent la plausibilit\u00e9 universelle. Ici, vos propres r\u00e8gles.\n",
                        "3 \u00e9tapes : Conditions (colonne vs valeur/colonne) \u2192 Expression R \u2192 Enregistrer\n",
                        "Export/import JSON pour centres multiples."),
                      paste0(
                        "\U0001F3AF GOAL: Build FITNESS-FOR-PURPOSE checks tailored to YOUR specific study.\n\n",
                        "WHY 'FITNESS-FOR-PURPOSE'?\n",
                        "The 77 built-in checks cover UNIVERSAL plausibility. YOUR study has SPECIFIC needs:\n",
                        "\u2022 Only patients 65+? \u2192 Flag age < 65\n",
                        "\u2022 Only I-chapter ICD? \u2192 Flag other codes\n",
                        "\u2022 Admission must precede procedure? \u2192 Check that\n\n",
                        "3 STEPS:\n",
                        "A. CONDITIONS: Choose 'Column vs. Value' or 'Column vs. Column' (can mix with AND/OR)\n",
                        "   Ex: (age > 120) AND (gender == 'male') or (admission_date > discharge_date)\n",
                        "B. GENERATE R QUERY: Auto-creates executable expression. Review it.\n",
                        "C. SAVE: Name + Severity + Description. Timestamp is automatic.\n\n",
                        "IMPORT/EXPORT: Share as JSON across centres for consistent validation."))),
      list(n = 5, t = switch(L(), de = "Ergebnisse & Interpretation", fr = "R\u00e9sultats & Interpr\u00e9tation", "Results & Interpretation"),
           b = switch(L(),
                      de = paste0(
                        "\U0001F3AF ZIEL: Datenqualit\u00e4t verstehen und Probleme lokalisieren.\n\n",
                        "DASHBOARD: Pr\u00fcfungen | Probleme | Betroffene | Quality Score\n",
                        "Score = 100% \u00d7 (1 \u2013 betroffene/Gesamt)\n\n",
                        "INTERPRETATION:\n",
                        "\u2705 100% = Exzellent | \U0001F535 95-99% = Gering | \U0001F7E1 80-95% = Moderat\n",
                        "\U0001F534 60-80% = Erheblich | \U0001F6A8 <60% = Kritisch\n\n",
                        "EXPORT: Word-Bericht (mit Grafiken) oder CSV"),
                      fr = paste0(
                        "\U0001F3AF OBJECTIF : Comprendre la qualit\u00e9 de vos donn\u00e9es.\n\n",
                        "Score = 100% \u00d7 (1 \u2013 affect\u00e9s/total)\n",
                        "Interpr\u00e9tation color\u00e9e de 100% (parfait) \u00e0 <60% (critique)\n",
                        "Export Word ou CSV."),
                      paste0(
                        "\U0001F3AF GOAL: Understand the data quality and locate problems.\n\n",
                        "DASHBOARD: Checks Run | Issues Found | Records Affected | Quality Score\n",
                        "Score = 100% \u00d7 (1 \u2013 affected/total). Example: 1000 patients, 50 affected \u2192 95%\n\n",
                        "INTERPRETATION (colour-coded):\n",
                        "\u2705 100% = Excellent | \U0001F535 95-99% = Minor | \U0001F7E1 80-95% = Moderate\n",
                        "\U0001F534 60-80% = Significant | \U0001F6A8 <60% = Critical \u2013 do NOT use without fixing\n\n",
                        "CHARTS: Severity distribution + Category breakdown\n",
                        "DETAIL TABLE: Every flagged record with row, check ID, severity, patient ID\n\n",
                        "EXPORT: Word Report (charts + tables) or CSV (raw data for own analysis)"))),
      list(n = 6, t = switch(L(), de = "Bereinigung & Dokumentation", fr = "Nettoyage & Documentation", "Cleansing & Documentation"),
           b = switch(L(),
                      de = paste0(
                        "\U0001F3AF ZIEL: Probleme beheben UND jede \u00c4nderung dokumentieren.\n\n",
                        "4 WERKZEUGE:\n",
                        "1. PROBLEMGEF\u00dcHRT: Problem w\u00e4hlen \u2192 Zeilen anzeigen \u2192 Beibehalten/Bearbeiten/L\u00f6schen\n",
                        "2. MASSENOPERATIONEN: Suchen & Ersetzen (Regex+Gro\u00df/Klein), Umbenennen, Datum-Fix, L\u00f6schen\n",
                        "3. MANUELL: Doppelklick auf Zelle wie in Excel\n",
                        "4. AUDIT-TRAIL: Zeitstempel + Aktion + Spalte + Zeile + alter/neuer Wert\n\n",
                        "\u21A9\uFE0F Alles r\u00fcckg\u00e4ngig machbar. Export: Bereinigte Daten (CSV) + Protokoll (Word/CSV)"),
                      fr = paste0(
                        "\U0001F3AF OBJECTIF : Corriger ET documenter chaque modification.\n\n",
                        "4 OUTILS :\n",
                        "1. GUID\u00c9 : Probl\u00e8me \u2192 Garder/\u00c9diter/Supprimer\n",
                        "2. EN MASSE : Chercher/remplacer (regex), renommer, dates, supprimer\n",
                        "3. MANUEL : Double-clic comme Excel\n",
                        "4. AUDIT : Chaque modification horodat\u00e9e\n\n",
                        "Tout r\u00e9versible. Export donn\u00e9es + journal."),
                      paste0(
                        "\U0001F3AF GOAL: Fix problems AND document every change for full traceability.\n\n",
                        "4 TOOLS:\n",
                        "1. ISSUE-GUIDED: Select issue \u2192 Show rows \u2192 Keep As Is / Edit Value / Delete\n",
                        "   'Keep As Is' = confirmed correct, logs the decision\n",
                        "   'Edit Value' = inline editor, click 'Save Edit' to confirm\n",
                        "   'Delete' = removes flagged rows (e.g. test data)\n\n",
                        "2. BULK OPS: Find & Replace (with Regex + Case options), Rename column, Fix dates, Delete column\n",
                        "   Ex: Replace 'M' with 'male' in gender column\n\n",
                        "3. MANUAL: Double-click any cell, type new value, Enter to save (like Excel)\n\n",
                        "4. AUDIT TRAIL: Every change logged with timestamp, action, column, row, old/new value\n",
                        "   Formal documentation for ethics committees and journal reviewers\n\n",
                        "\u21A9\uFE0F UNDO: Every operation reversible. Full state preserved.\n",
                        "EXPORT: Cleaned data (CSV) + Change log (Word/CSV) + Comparison view"))))
    tagList(lapply(steps, function(s)
      div(class = "odqa-tut-card",
          div(class = "odqa-tut-header", div(class = "odqa-tut-num", s$n), div(class = "odqa-tut-title", s$t), span(class = "odqa-tut-chevron", "\u25BC")),
          div(class = "odqa-tut-body", s$b))))
  })
  
  # ── Step Header & Label Outputs ─────────────────────────────────────────────
  output$s1_header <- renderUI(tagList(h2(t("s1_title"))))
  output$s1_source_hint <- renderUI(span(t("s1_source")))
  output$s1_preview_title <- renderUI(span(t("s1_preview")))
  output$s2_header <- renderUI(tagList(h2(t("s2_title")), p(t("s2_info"))))
  output$s2_gender_title <- renderUI(span(t("s2_gender")))
  output$s2_gender_explain <- renderUI(span(t("s2_gender_why")))
  output$s3_header <- renderUI(tagList(h2(t("s3_title"))))
  output$s3_hint <- renderUI(span(t("s3_info")))
  output$s4_header <- renderUI(tagList(h2(t("s4_title"))))
  output$s4_hint <- renderUI(span(t("s4_info")))
  output$s4a_title <- renderUI(span(t("s4_a")))
  output$s4a_hint <- renderUI(span(t("s4_a_hint")))
  output$s4b_title <- renderUI(span(t("s4_b")))
  output$s4b_hint <- renderUI(span(t("s4_b_hint")))
  output$s4c_title <- renderUI(span(t("s4_c")))
  output$s4c_hint <- renderUI(span(t("s4_c_hint")))
  output$s5_header <- renderUI(tagList(h2(t("s5_title"))))
  output$s6_header <- renderUI(tagList(h2(t("s6_title"))))
  output$s6_guide_title <- renderUI(span(t("s6_guide")))
  output$s6_guide_sub <- renderUI(span(t("s6_guide_hint")))
  output$s6_bulk_title <- renderUI(span(t("s6_bulk")))
  output$s6_manual_title <- renderUI(span(t("s6_manual")))
  output$s6_log_title <- renderUI(span(t("s6_log")))
  output$s6_compare_title <- renderUI(span(t("s6_compare")))
  output$s6_rename_title <- renderUI(span(t("s6_rename")))
  output$s6_datefix_title <- renderUI(span(t("s6_datefix")))
  output$chart_sev_title <- renderUI(h4(t("s5_sev")))
  output$chart_cat_title <- renderUI(h4(t("s5_cat")))
  output$detail_title <- renderUI(div(class = "odqa-card-header", div(class = "odqa-card-badge", "\U0001F50D"), div(class = "odqa-card-title", t("s5_detail"))))
  output$footer_indicator <- renderUI({
    s <- rv$step
    if (identical(s, "T")) span("Tutorial")
    else if (identical(s, "F")) span("Summary")
    else if (is.numeric(s) && s > 0) span(paste0(switch(L(), de = "Schritt ", fr = "\u00c9tape ", "Step "), s, " / 6"))
    else span("Open DQA V0.1")
  })
  
  # Button labels
  observe({
    updateActionButton(session, "btn_load", label = t("btn_load"))
    updateActionButton(session, "btn_map_save", label = t("btn_save"))
    updateActionButton(session, "btn_run", label = t("btn_run"))
    updateActionButton(session, "btn_sel_all", label = t("btn_selall"))
    updateActionButton(session, "btn_desel", label = t("btn_desel"))
    updateActionButton(session, "btn_prev", label = t("btn_back"))
    updateActionButton(session, "btn_next_f", label = t("btn_next"))
    updateActionButton(session, "btn_finish", label = t("btn_finish"))
    updateActionButton(session, "btn_new_analysis", label = t("finish_new"))
  })
  
  # ── Finish Page ─────────────────────────────────────────────────────────────
  observeEvent(input$btn_finish, go("F"))
  # Hide Next button on finish page
  observe({
    if (identical(rv$step, "F")) {
      shinyjs::hide("btn_next_f")
    } else {
      shinyjs::show("btn_next_f")
    }
  })
  # ── Hide Back button on Welcome page (Step 0) ──────────────────────────────
  observe({
    s <- rv$step
    if (identical(s, 0L) || identical(s, 0)) {
      shinyjs::hide("btn_prev")
    } else {
      shinyjs::show("btn_prev")
    }
  })  
  observeEvent(input$btn_new_analysis, {
    rv$raw <- NULL; rv$mapped <- NULL; rv$mapping <- list()
    rv$checks_df <- mk_checks(); rv$custom_checks <- list()
    rv$ai_suggestions <- list(); rv$data_fingerprint <- NULL
    rv$issues <- NULL; rv$cl_data <- NULL; rv$cl_log <- rv$cl_log[0, ]; rv$cl_undo_stack <- list()
    rv$compare_ready <- FALSE; rv$step <- 0; rv$max_step <- 0
    session$sendCustomMessage("goto_step", 0); session$sendCustomMessage("enable_pills", 0)
  })
  output$finish_title_ui <- renderUI(span(t("finish_title")))
  output$finish_feedback_ui <- renderUI(span(t("finish_feedback")))
  output$finish_recap_ui <- renderUI({
    nr <- if (!is.null(rv$mapped)) nrow(rv$mapped) else 0
    ni <- if (!is.null(rv$issues)) nrow(rv$issues) else 0
    nc <- if (!is.null(rv$cl_log)) nrow(rv$cl_log) else 0
    imp_t <- if (!is.null(rv$import_time)) paste0(round(rv$import_time, 2), "s") else "N/A"
    chk_t <- if (!is.null(rv$check_time)) paste0(round(rv$check_time, 2), "s") else "N/A"
    has_email <- nzchar(rv$user_info$email %||% "")
    div(class = "recap",
        h3(t("finish_recap")),
        div(class = "recap-item", span("\U0001F4CA"), span(paste("Records analysed:", nr))),
        div(class = "recap-item", span("\u26A0\uFE0F"), span(paste("Issues detected:", ni))),
        div(class = "recap-item", span("\U0001F9F9"), span(paste("Cleansing actions:", nc))),
        div(class = "recap-item", span("\u23F1"), span(paste("Import:", imp_t, "| Checks:", chk_t))),
        div(class = "recap-item", span("\U0001F4C4"), span("Reports: Quality Report (Word), Issues (CSV), Change Log (Word/CSV)")),
        div(class = "recap-item", span("\U0001F4BE"), span("Cleaned dataset: available for download")),
        if (has_email) div(class = "recap-item", span("\u2709"), span(t("finish_email_sent")))
        else div(class = "recap-item", span("\u2709"), span(t("finish_email_skip"))),
        if (nzchar(rv$user_info$name %||% "")) div(class = "recap-item", span("\U0001F464"), span(paste("Analyst:", rv$user_info$name)))
    )
  })
  
  # ── SQL Templates ───────────────────────────────────────────────────────────
  observeEvent(input$sql_tpl_basic, updateTextAreaInput(session, "sql_query", value = "SELECT *\nFROM my_schema.my_table\nLIMIT 1000;"))
  observeEvent(input$sql_tpl_i2b2, updateTextAreaInput(session, "sql_query", value = paste0(
    "SELECT\n  p.patient_num AS patient_id,\n  o.concept_cd AS icd,\n",
    "  o.start_date AS admission_date,\n  o.end_date AS discharge_date,\n",
    "  pd.sex_cd AS gender,\n",
    "  EXTRACT(YEAR FROM AGE(o.start_date, pd.birth_date)) AS age\n",
    "FROM i2b2demodata.observation_fact o\n",
    "JOIN i2b2demodata.patient_dimension pd ON o.patient_num = pd.patient_num\n",
    "WHERE o.concept_cd LIKE 'ICD%'\nLIMIT 1000;")))
  observeEvent(input$sql_tpl_omop, updateTextAreaInput(session, "sql_query", value = paste0(
    "SELECT\n  co.person_id AS patient_id,\n  c.concept_code AS icd,\n",
    "  vo.visit_start_date AS admission_date,\n  vo.visit_end_date AS discharge_date,\n",
    "  CASE p.gender_concept_id WHEN 8507 THEN 'male' WHEN 8532 THEN 'female' END AS gender,\n",
    "  EXTRACT(YEAR FROM AGE(vo.visit_start_date, make_date(p.year_of_birth,1,1))) AS age\n",
    "FROM cdm.condition_occurrence co\nJOIN cdm.concept c ON co.condition_concept_id = c.concept_id\n",
    "JOIN cdm.visit_occurrence vo ON co.visit_occurrence_id = vo.visit_occurrence_id\n",
    "JOIN cdm.person p ON co.person_id = p.person_id\nLIMIT 1000;")))
  observeEvent(input$btn_sql_test, {
    tryCatch({
      if (input$sql_type == "PostgreSQL" && !sql_pg) stop("Install DBI & RPostgres")
      if (input$sql_type == "Microsoft SQL" && !sql_ms) stop("Install DBI & odbc")
      if (input$sql_type == "PostgreSQL") {
        con <- DBI::dbConnect(RPostgres::Postgres(), host = input$sql_host, port = as.integer(input$sql_port), dbname = input$sql_db, user = input$sql_user, password = input$sql_pw)
        DBI::dbDisconnect(con)
      }
      safe_notify("\u2705 Connection successful!", "message")
    }, error = function(e) safe_notify(paste("\u274C", e$message), "error"))
  })
  observeEvent(input$btn_sql_run, {
    tryCatch({
      df <- with_waiter(read_sql_query(input$sql_host, input$sql_port, input$sql_db, input$sql_user, input$sql_pw, input$sql_query, input$sql_type), "Querying\u2026")
      rv$raw <- df; safe_notify(paste("\u2705", nrow(df), "rows loaded"), "message")
      rv$max_step <- max(rv$max_step, 2); session$sendCustomMessage("enable_pills", rv$max_step)
    }, error = function(e) safe_notify(paste("\u274C", e$message), "error"))
  })
  
  # ── FHIR Server ─────────────────────────────────────────────────────────────
  observeEvent(input$btn_fhir_test, {
    tryCatch({
      url <- paste0(trimws(input$fhir_url), "/metadata")
      resp <- httr::GET(url, httr::timeout(10))
      if (httr::status_code(resp) < 400) safe_notify("\u2705 FHIR server responded!", "message")
      else safe_notify(paste("\u274C Status:", httr::status_code(resp)), "error")
    }, error = function(e) safe_notify(paste("\u274C", e$message), "error"))
  })
  observeEvent(input$btn_fhir_run, {
    tryCatch({
      url <- paste0(trimws(input$fhir_url), "/", trimws(input$fhir_query))
      resp <- with_waiter(httr::GET(url, httr::timeout(30)), "Fetching FHIR data\u2026")
      if (httr::status_code(resp) >= 400) stop(paste("HTTP", httr::status_code(resp)))
      bundle <- jsonlite::fromJSON(httr::content(resp, "text", encoding = "UTF-8"), simplifyVector = FALSE)
      # Write temp file and parse as FHIR bundle
      tmp <- tempfile(fileext = ".json")
      jsonlite::write_json(bundle, tmp, auto_unbox = TRUE)
      df <- read_fhir_tabular(tmp)
      rv$raw <- df; safe_notify(paste("\u2705", nrow(df), "rows from FHIR"), "message")
      rv$max_step <- max(rv$max_step, 2); session$sendCustomMessage("enable_pills", rv$max_step)
    }, error = function(e) safe_notify(paste("\u274C", e$message), "error"))
  })
  
  # ── File Load ───────────────────────────────────────────────────────────────
  observeEvent(input$btn_load, {
    t_start <- proc.time()
    df <- tryCatch(with_waiter(
      read_file(input$file_type, csv_f = input$file_csv, csv_h = input$csv_header, csv_s = input$csv_sep,
                xls_f = input$file_csv, xls_sh = input$xls_sheet, json_f = input$file_csv, fhir_f = input$file_csv),
      t("loading")), error = function(e) NULL)
    elapsed <- (proc.time() - t_start)[["elapsed"]]
    if (is.null(df) || nrow(df) == 0) { safe_notify("\u274C No data loaded.", "error"); return() }
    rv$raw <- df; rv$import_time <- elapsed
    rv$perf_log <- rbind(rv$perf_log, data.frame(task = "Import", source = input$file_type, rows = as.integer(nrow(df)), duration_sec = round(elapsed, 3), timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), stringsAsFactors = FALSE))
    safe_notify(paste("\u2705", nrow(df), "rows,", ncol(df), "cols |", round(elapsed, 2), "s"), "message")
    rv$max_step <- max(rv$max_step, 2); session$sendCustomMessage("enable_pills", rv$max_step)
  })
  output$dt_preview <- renderDT({
    req(rv$raw)
    datatable(head(rv$raw, 200), options = list(pageLength = 10, scrollX = TRUE, dom = "tip"), class = "compact stripe", rownames = FALSE)
  })
  
  # ── Column Mapping ──────────────────────────────────────────────────────────
  output$mapping_ui <- renderUI({
    req(rv$raw); cn <- names(rv$raw); am <- auto_map(cn)
    targets <- c("patient_id", "icd", "ops", "gender", "admission_date", "discharge_date", "age", "birth_date", "anamnese")
    choices <- c("(none)" = "", setNames(cn, cn))
    tagList(lapply(targets, function(tg) {
      sel <- am[[tg]] %||% ""
      fluidRow(column(4, tags$label(tg, style = "font-weight:700;margin-top:10px;")),
               column(8, selectInput(paste0("map_", tg), NULL, choices = choices, selected = sel, width = "100%")))
    }))
  })
  observeEvent(input$btn_map_save, {
    req(rv$raw)
    targets <- c("patient_id", "icd", "ops", "gender", "admission_date", "discharge_date", "age", "birth_date", "anamnese")
    mp <- setNames(lapply(targets, function(tg) input[[paste0("map_", tg)]]), targets)
    mp <- mp[vapply(mp, function(v) !is.null(v) && nzchar(v), logical(1))]
    df <- rv$raw
    for (tg in names(mp)) if (mp[[tg]] %in% names(df) && mp[[tg]] != tg) df[[tg]] <- df[[mp[[tg]]]]
    gmap <- list(male = input$gmap_m, female = input$gmap_f)
    if ("gender" %in% names(df)) df$gender <- std_gender(df$gender, gmap)
    for (dc in c("admission_date", "discharge_date", "birth_date"))
      if (dc %in% names(df)) df[[dc]] <- suppressWarnings(as.Date(as.character(df[[dc]])))
    if ("age" %in% names(df)) df$age <- suppressWarnings(as.numeric(df$age))
    rv$mapped <- df; rv$mapping <- mp
    rv$cl_data <- data.table::as.data.table(df)
    safe_notify("\u2705 Columns mapped!", "message")
    rv$max_step <- max(rv$max_step, 5); session$sendCustomMessage("enable_pills", rv$max_step); go(3)
  })
  
  # ── Built-in Check Categories (colour-coded by availability) ────────────────
  output$check_categories <- renderUI({
    mapped_cols <- if (!is.null(rv$mapped)) names(rv$mapped) else character(0)
    cats <- list(
      list(name = "Completeness", icon = "\U0001F4CB", color = "#0866FF", ids = paste0("cat1_", 1:16)),
      list(name = "Age Plausibility", icon = "\U0001F476", color = "#7C3AED", ids = paste0("cat2_", 1:15)),
      list(name = "Gender Plausibility", icon = "\u2640\u2642", color = "#EC4899", ids = paste0("cat3_", 1:15)),
      list(name = "Temporal Consistency", icon = "\u23F0", color = "#F59E0B", ids = grep("^cat4_", names(CL), value = TRUE)),
      list(name = "Diagnosis-Procedure", icon = "\U0001F3E5", color = "#10B981", ids = paste0("cat5_", 1:15)),
      list(name = "Code Integrity", icon = "\U0001F50D", color = "#EF4444", ids = grep("^cat6_", names(CL), value = TRUE)))
    cdf <- rv$checks_df
    tagList(lapply(cats, function(ct) {
      sub <- cdf[cdf$check_id %in% ct$ids, ]
      div(class = "odqa-check-cat",
          div(class = "odqa-check-cat-header",
              div(class = "odqa-check-cat-icon", style = paste0("background:", ct$color, "20;color:", ct$color, ";"), ct$icon),
              div(class = "odqa-check-cat-name", ct$name),
              div(class = "odqa-check-cat-count", paste0(nrow(sub), " checks"))),
          div(style = "padding:10px 18px;",
              checkboxGroupInput(paste0("chk_", ct$ids[1]), NULL,
                                 choiceNames = lapply(1:nrow(sub), function(i) {
                                   needed <- strsplit(sub$required[i], ", ")[[1]]
                                   avail <- all(needed %in% mapped_cols)
                                   cls <- if (avail) "check-available" else "check-unavailable"
                                   div(class = cls, style = "display:flex;gap:8px;align-items:center;padding:2px 0;",
                                       span(sub$check_id[i], style = "font-size:10px;color:var(--text-tertiary);width:70px;"),
                                       span(sub$check_name[i], style = "font-size:12px;font-weight:700;"),
                                       span(sub$description[i], style = "font-size:12px;color:var(--text-tertiary);"),
                                       if (!avail) span(paste0("(needs: ", sub$required[i], ")"), style = "font-size:10px;color:var(--danger);margin-left:auto;"))
                                 }),
                                 choiceValues = sub$check_id,
                                 selected = sub$check_id[vapply(1:nrow(sub), function(i) all(strsplit(sub$required[i], ", ")[[1]] %in% mapped_cols), logical(1))])))
    }))
  })
  observeEvent(input$btn_sel_all, {
    cats <- list(paste0("cat1_", 1:16), paste0("cat2_", 1:15), paste0("cat3_", 1:15), grep("^cat4_", names(CL), value = TRUE), paste0("cat5_", 1:15), grep("^cat6_", names(CL), value = TRUE))
    for (ct in cats) updateCheckboxGroupInput(session, paste0("chk_", ct[1]), selected = ct)
  })
  observeEvent(input$btn_desel, {
    cats <- list(paste0("cat1_", 1:16), paste0("cat2_", 1:15), paste0("cat3_", 1:15), grep("^cat4_", names(CL), value = TRUE), paste0("cat5_", 1:15), grep("^cat6_", names(CL), value = TRUE))
    for (ct in cats) updateCheckboxGroupInput(session, paste0("chk_", ct[1]), selected = character(0))
  })
  get_selected_checks <- reactive({
    ids <- c()
    cats <- list(paste0("cat1_", 1:16), paste0("cat2_", 1:15), paste0("cat3_", 1:15), grep("^cat4_", names(CL), value = TRUE), paste0("cat5_", 1:15), grep("^cat6_", names(CL), value = TRUE))
    for (ct in cats) ids <- c(ids, input[[paste0("chk_", ct[1])]])
    ids
  })
  
  
  # ── Custom Check Builder ────────────────────────────────────────────────────
  # ── Step 4: Builder Inputs (wide-data safe) ────────────────────────────────
  get_cb_col <- function() {
    if (!is.null(input$cb_col_txt) && nzchar(trimws(input$cb_col_txt))) return(trimws(input$cb_col_txt))
    input$cb_col %||% ""
  }
  get_cb_col2 <- function() {
    if (!is.null(input$cb_col2_txt) && nzchar(trimws(input$cb_col2_txt))) return(trimws(input$cb_col2_txt))
    input$cb_col2 %||% ""
  }
  
  output$cb_col_ui <- renderUI({
    req(rv$mapped)
    cn <- names(rv$mapped)
    if (length(cn) <= 100000) {
      selectizeInput("cb_col", "Column", choices = cn, multiple = FALSE,
                     options = list(placeholder = "Type to search...", maxOptions = 5000),
                     width = "100%")
    } else {
      textInput("cb_col_txt", "Column", "", placeholder = "Type exact column name (dataset is very wide)", width = "100%")
    }
  })
  
  output$cb_val_or_col_ui <- renderUI({
    req(rv$mapped)
    ctype <- input$cb_comp_type %||% "val"
    op <- input$cb_op %||% "=="
    
    cn <- names(rv$mapped)
    
    if (ctype == "col") {
      if (length(cn) <= 100000) {
        selectizeInput("cb_col2", "Compare Column", choices = cn, multiple = FALSE,
                       options = list(placeholder = "Type to search...", maxOptions = 5000),
                       width = "100%")
      } else {
        textInput("cb_col2_txt", "Compare Column", "", placeholder = "Type exact column name", width = "100%")
      }
    } else {
      if (op %in% c("is.na", "is_not.na")) {
        div(class = "hint", "No value required for this operator.")
      } else if (op %in% c("BETWEEN", "NOT BETWEEN")) {
        tagList(
          textInput("cb_val1", "Value (min)", "", width = "100%"),
          textInput("cb_val2", "Value (max)", "", width = "100%")
        )
      } else if (op %in% c("IN", "NOT IN")) {
        coln <- get_cb_col()
        choices <- character(0)
        if (nzchar(coln) && coln %in% cn) {
          x <- rv$mapped[[coln]]
          if (length(x) > 50000) x <- x[sample.int(length(x), 50000)]
          ux <- unique(na.omit(trimws(as.character(x))))
          ux <- ux[nzchar(ux)]
          if (length(ux) <= 200) choices <- sort(ux)
        }
        if (length(choices) > 0) {
          selectizeInput("cb_val_in", "Values", choices = choices, multiple = TRUE,
                         options = list(placeholder = "Select one or more values"),
                         width = "100%")
        } else {
          textAreaInput("cb_val_csv", "Values (comma-separated)", "", width = "100%", rows = 2,
                        placeholder = 'Example: "m","f"   or   1,2,3')
        }
      } else {
        textInput("cb_val", "Value", "", width = "100%")
      }
    }
  })
  
  observeEvent(input$cb_add, {
    req(rv$mapped)
    col <- get_cb_col()
    op <- input$cb_op %||% ""
    req(nzchar(col), nzchar(op))
    
    ctype <- input$cb_comp_type %||% "val"
    val_text <- ""
    
    if (ctype == "col") {
      col2 <- get_cb_col2()
      req(nzchar(col2))
      val_text <- paste0("[col]", col2)
    } else {
      if (op %in% c("is.na", "is_not.na")) {
        val_text <- ""
      } else if (op %in% c("BETWEEN", "NOT BETWEEN")) {
        v1 <- input$cb_val1 %||% ""
        v2 <- input$cb_val2 %||% ""
        req(nzchar(v1), nzchar(v2))
        val_text <- paste0("[bw]", v1, "||", v2)
      } else if (op %in% c("IN", "NOT IN")) {
        if (!is.null(input$cb_val_in) && length(input$cb_val_in) > 0) {
          val_text <- paste0("[in]", paste(input$cb_val_in, collapse = "||"))
        } else {
          val_text <- trimws(input$cb_val_csv %||% "")
          req(nzchar(val_text))
          val_text <- paste0("[csv]", val_text)
        }
      } else {
        val_text <- input$cb_val %||% ""
        req(nzchar(val_text))
      }
    }
    
    rv$conditions <- rbind(
      rv$conditions,
      data.frame(
        column = col, operator = op, value = val_text,
        logic = input$cb_logic %||% "(end)",
        stringsAsFactors = FALSE
      )
    )
  })
  
  observeEvent(input$cb_clear, {
    rv$conditions <- rv$conditions[0, ]
    rv$cb_expr <- ""
  })
  
  output$dt_conditions <- renderDT({
    if (nrow(rv$conditions) == 0) {
      return(datatable(
        data.frame(column = character(), operator = character(), value = character(), logic = character()),
        options = list(dom = "t", pageLength = 10), rownames = FALSE, class = "compact"
      ))
    }
    datatable(rv$conditions, options = list(dom = "t", pageLength = 20, scrollX = TRUE),
              rownames = FALSE, class = "compact")
  })
  
  observeEvent(input$cb_edit_expr, {
    showModal(modalDialog(
      title = "Edit Expression",
      textareaInput("cb_expr_raw_edit", NULL, value = rv$cb_expr, width = "100%", rows = 8),
      div(class = "hint", "Expression must return TRUE for rows that should be flagged as issues."),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("cb_expr_save", "Save", class = "btn-odqa btn-odqa-primary")
      ),
      easyClose = TRUE
    ))
  })
  observeEvent(input$cb_expr_save, {
    req(input$cb_expr_raw_edit)
    rv$cb_expr <- trimws(input$cb_expr_raw_edit)
    removeModal()
  })
  
  observeEvent(input$cb_gen, {
    req(nrow(rv$conditions) > 0)
    cn <- names(rv$mapped)
    
    # ══════════════════════════════════════════════════════════════════════════
    # EXPRESSION COMPILER v3.0 — IT-Security-Grade, Data-Format-Aware
    # ══════════════════════════════════════════════════════════════════════════
    
    # ── [SEC-1] Input Sanitization Firewall ──────────────────────────────────
    # Whitelist: only allow values that match safe patterns.
    # Blacklist: reject anything that looks like R code injection.
    sec_blacklist <- c(
      "system", "exec", "shell", "pipe", "download", "source", "eval",
      "parse", "assign", "rm\\(", "file\\.", "readLines", "writeLines",
      "unlink", "library", "require", "install", "Sys\\.", "proc\\.time",
      "options\\(", "setwd", "getwd", "\\bdo\\.call\\b", "\\bget\\b\\(",
      "environment", "globalenv", "baseenv", "new\\.env", "\\$"
    )
    sec_blacklist_rx <- paste0("(", paste(sec_blacklist, collapse = "|"), ")")
    
    sanitize_value <- function(v) {
      v <- trimws(as.character(v))
      if (grepl(sec_blacklist_rx, v, ignore.case = TRUE, perl = TRUE)) {
        stop("[SEC] Blocked: value contains forbidden pattern", call. = FALSE)
      }
      # Strip any backtick injection attempts in values
      v <- gsub("`", "", v, fixed = TRUE)
      v
    }
    
    validate_column <- function(col_name) {
      col_name <- trimws(as.character(col_name))
      if (!col_name %in% cn) {
        stop(paste0("[SEC] Column '", col_name, "' does not exist in dataset"), call. = FALSE)
      }
      col_name
    }
    
    # ── [SEC-2] Safe Escape (extended) ───────────────────────────────────────
    esc_sq <- function(x) {
      x <- gsub("\\", "\\\\", x, fixed = TRUE)  # escape backslashes first
      x <- gsub("'", "\\'", x, fixed = TRUE)     # then single quotes
      x
    }
    
    # ── [FMT-1] Data-Format-Aware Value Formatter ────────────────────────────
    # Introspects the actual column class in rv$mapped to produce the correct
    # R literal. Handles: numeric, integer, Date, POSIXct, logical, character.
    fmt_value <- function(col_name, v_raw) {
      v_raw <- sanitize_value(v_raw)
      
      # Numeric literal detection (integers and doubles)
      num <- suppressWarnings(as.numeric(v_raw))
      if (!is.na(num) && !grepl("[A-Za-z]", v_raw)) return(v_raw)
      
      # Logical literal detection
      if (toupper(v_raw) %in% c("TRUE", "FALSE")) return(toupper(v_raw))
      
      # Column-class-aware formatting
      if (col_name %in% cn) {
        cls <- class(rv$mapped[[col_name]])
        
        # ── Date columns ──
        if ("Date" %in% cls) {
          # Try multiple date formats (YYYY-MM-DD, DD.MM.YYYY, MM/DD/YYYY, YYYYMMDD)
          date_formats <- c("%Y-%m-%d", "%d.%m.%Y", "%m/%d/%Y", "%Y%m%d", "%d/%m/%Y")
          for (fmt in date_formats) {
            d <- tryCatch(as.Date(v_raw, format = fmt), error = function(e) NA)
            if (!is.na(d)) {
              return(paste0("as.Date('", format(d, "%Y-%m-%d"), "')"))
            }
          }
        }
        
        # ── POSIXct / POSIXlt columns ──
        if (any(c("POSIXct", "POSIXlt") %in% cls)) {
          dt_formats <- c(
            "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M:%S",
            "%d.%m.%Y %H:%M:%S", "%m/%d/%Y %H:%M:%S", "%Y-%m-%d"
          )
          for (fmt in dt_formats) {
            d <- tryCatch(as.POSIXct(v_raw, format = fmt), error = function(e) NA)
            if (!is.na(d)) {
              return(paste0("as.POSIXct('", format(d, "%Y-%m-%d %H:%M:%S"), "')"))
            }
          }
        }
        
        # ── Integer columns: preserve integer type ──
        if ("integer" %in% cls && !is.na(num)) {
          return(paste0(as.integer(num), "L"))
        }
      }
      
      # Default: string literal (safely escaped)
      paste0("'", esc_sq(v_raw), "'")
    }
    
    # ── [EXPR-1] NA-Safe Expression Wrappers ─────────────────────────────────
    # Every comparison is wrapped so that NA inputs → FALSE (not NA),
    # preventing silent row loss in which().
    
    na_safe_cmp <- function(col_sym, op_str, val_str) {
      # Produces: (!is.na(col) & (col op val))
      paste0("(!is.na(", col_sym, ") & (", col_sym, " ", op_str, " ", val_str, "))")
    }
    
    na_safe_grepl <- function(pattern_str, col_sym, extra_args) {
      # Produces: (!is.na(col) & grepl(pattern, col, ...))
      paste0("(!is.na(", col_sym, ") & grepl('", esc_sq(pattern_str), "', ",
             col_sym, ", ", extra_args, "))")
    }
    
    na_safe_not_grepl <- function(pattern_str, col_sym, extra_args) {
      # Produces: (!is.na(col) & !grepl(pattern, col, ...))
      paste0("(!is.na(", col_sym, ") & !grepl('", esc_sq(pattern_str), "', ",
             col_sym, ", ", extra_args, "))")
    }
    
    # ── [EXPR-2] Column-vs-Column Expression Builder ─────────────────────────
    # Handles ALL 17 operators correctly when comparing two columns.
    build_col_vs_col <- function(col1_sym, col2_sym, op) {
      both_notna <- paste0("(!is.na(", col1_sym, ") & !is.na(", col2_sym, "))")
      
      switch(op,
             "==" =, "!=" =, ">" =, ">=" =, "<" =, "<=" =
               paste0("(", both_notna, " & (", col1_sym, " ", op, " ", col2_sym, "))"),
             "contains" =
               paste0("(", both_notna, " & grepl(as.character(", col2_sym, "), as.character(",
                      col1_sym, "), fixed = TRUE))"),
             "not_contains" =
               paste0("(", both_notna, " & !grepl(as.character(", col2_sym, "), as.character(",
                      col1_sym, "), fixed = TRUE))"),
             "starts_with" =
               paste0("(", both_notna, " & startsWith(as.character(", col1_sym,
                      "), as.character(", col2_sym, ")))"),
             "ends_with" =
               paste0("(", both_notna, " & endsWith(as.character(", col1_sym,
                      "), as.character(", col2_sym, ")))"),
             "is.na" =  paste0("is.na(", col1_sym, ")"),
             "is_not.na" = paste0("!is.na(", col1_sym, ")"),
             "BETWEEN" =, "NOT BETWEEN" =, "IN" =, "NOT IN" =, "REGEXP" = {
               safe_notify(paste0("Operator '", op,
                                  "' is not supported for column-vs-column comparisons. Use Column vs. Value instead."),
                           "warning")
               "FALSE"
             },
             # Fallback for arithmetic operators
             paste0("(", both_notna, " & (", col1_sym, " ", op, " ", col2_sym, "))")
      )
    }
    
    # ── [EXPR-3] Master Expression Builder ───────────────────────────────────
    build_expr <- function(col, op, val) {
      # [SEC-3] Validate column exists
      col <- validate_column(col)
      s <- safe_sym(col)  # Backtick-quoted if needed
      
      # ── Column-vs-Column path ──
      if (grepl("^\\[col\\]", val)) {
        col2_name <- sub("^\\[col\\]", "", val)
        col2_name <- validate_column(col2_name)
        s2 <- safe_sym(col2_name)
        return(build_col_vs_col(s, s2, op))
      }
      
      # ── Unary operators (no value needed) ──
      if (op == "is.na")     return(paste0("is.na(", s, ")"))
      if (op == "is_not.na") return(paste0("!is.na(", s, ")"))
      
      # ── BETWEEN / NOT BETWEEN ──
      if (op %in% c("BETWEEN", "NOT BETWEEN")) {
        parts <- if (grepl("^\\[bw\\]", val)) {
          strsplit(sub("^\\[bw\\]", "", val), "\\|\\|")[[1]]
        } else {
          trimws(strsplit(val, "AND", fixed = TRUE)[[1]])
        }
        if (length(parts) < 2) return("FALSE")
        v1 <- fmt_value(col, trimws(parts[1]))
        v2 <- fmt_value(col, trimws(parts[2]))
        if (op == "BETWEEN") {
          return(paste0("(!is.na(", s, ") & (", s, " >= ", v1, " & ", s, " <= ", v2, "))"))
        } else {
          return(paste0("(!is.na(", s, ") & (", s, " < ", v1, " | ", s, " > ", v2, "))"))
        }
      }
      
      # ── IN / NOT IN ──
      if (op %in% c("IN", "NOT IN")) {
        vals_vec <- if (grepl("^\\[in\\]", val)) {
          strsplit(sub("^\\[in\\]", "", val), "\\|\\|")[[1]]
        } else if (grepl("^\\[csv\\]", val)) {
          unlist(strsplit(sub("^\\[csv\\]", "", val), ",", fixed = TRUE))
        } else {
          unlist(strsplit(val, ",", fixed = TRUE))
        }
        vals_vec <- trimws(vals_vec)
        vals_vec <- vals_vec[nzchar(vals_vec)]
        if (length(vals_vec) == 0) return("FALSE")
        
        # Type-aware vectorisation: format EVERY value through fmt_value
        # (no more fragile 90% numeric threshold)
        formatted <- vapply(vals_vec, function(v) {
          v <- gsub('^"|"$', "", v)  # strip optional user-level quoting
          fmt_value(col, v)
        }, character(1), USE.NAMES = FALSE)
        
        cvec <- paste(formatted, collapse = ", ")
        
        if (op == "IN") {
          return(paste0("(!is.na(", s, ") & (", s, " %in% c(", cvec, ")))"))
        } else {
          return(paste0("(!is.na(", s, ") & !(", s, " %in% c(", cvec, ")))"))
        }
      }
      
      # ── Pattern-matching operators (grepl-based) ──
      if (op == "REGEXP") {
        v <- sanitize_value(val)
        return(na_safe_grepl(v, s, "perl = TRUE"))
      }
      if (op == "contains") {
        v <- sanitize_value(val)
        return(na_safe_grepl(v, s, "ignore.case = TRUE"))
      }
      if (op == "not_contains") {
        v <- sanitize_value(val)
        return(na_safe_not_grepl(v, s, "ignore.case = TRUE"))
      }
      if (op == "starts_with") {
        v <- sanitize_value(val)
        return(na_safe_grepl(paste0("^", esc_sq(v)), s, "ignore.case = TRUE"))
        # Note: double-escaping avoided because na_safe_grepl calls esc_sq internally.
        # Override: pass pre-built pattern directly.
      }
      if (op == "ends_with") {
        v <- sanitize_value(val)
        return(na_safe_grepl(paste0(esc_sq(v), "$"), s, "ignore.case = TRUE"))
      }
      
      # ── Standard comparison operators (==, !=, >, >=, <, <=) ──
      v <- fmt_value(col, val)
      na_safe_cmp(s, op, v)
    }
    
    # ── [FIX] starts_with / ends_with: override na_safe_grepl to avoid
    #    double-escaping (esc_sq is called inside na_safe_grepl AND in the
    #    pattern construction). Use direct paste instead. ──
    build_expr_safe <- function(col, op, val) {
      col <- validate_column(col)
      s <- safe_sym(col)
      
      if (op == "starts_with") {
        v <- sanitize_value(val)
        return(paste0("(!is.na(", s, ") & grepl('^", esc_sq(v), "', ", s, ", ignore.case = TRUE))"))
      }
      if (op == "ends_with") {
        v <- sanitize_value(val)
        return(paste0("(!is.na(", s, ") & grepl('", esc_sq(v), "$', ", s, ", ignore.case = TRUE))"))
      }
      build_expr(col, op, val)
    }
    
    # ── [COMPILE] Assemble all conditions ────────────────────────────────────
    compile_ok <- TRUE
    parts <- lapply(seq_len(nrow(rv$conditions)), function(i) {
      r <- rv$conditions[i, ]
      expr <- tryCatch(
        build_expr_safe(r$column, r$operator, r$value),
        error = function(e) {
          safe_notify(paste0("Condition #", i, ": ", e$message), "error")
          compile_ok <<- FALSE
          "FALSE"
        }
      )
      if (r$logic %in% c("AND", "OR") && i < nrow(rv$conditions)) {
        paste0(expr, if (r$logic == "AND") " & " else " | ")
      } else {
        expr
      }
    })
    
    rv$cb_expr <- paste0(parts, collapse = "")
    
    # ── [SEC-4] Final expression validation ──────────────────────────────────
    if (compile_ok && nzchar(rv$cb_expr)) {
      parsed <- tryCatch(rlang::parse_expr(rv$cb_expr), error = function(e) e)
      if (inherits(parsed, "error")) {
        safe_notify(paste0("Generated expression is not valid R: ", parsed$message), "error")
        rv$cb_expr <- ""
      }
    }
  })
  
  output$cb_expr_preview <- renderText(rv$cb_expr)
  
  observeEvent(input$cb_save, {
    req(nzchar(rv$cb_expr), nzchar(input$cb_name))
    new_check <- list(
      check_id       = paste0("custom_", gsub("[^a-zA-Z0-9]", "_", input$cb_name), "_", as.integer(Sys.time())),
      description    = if (nzchar(input$cb_desc)) input$cb_desc else input$cb_name,
      expression_raw = rv$cb_expr,
      severity       = input$cb_sev,
      created        = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )
    rv$custom_checks <- c(rv$custom_checks, list(new_check))
    rv$conditions <- rv$conditions[0, ]
    rv$cb_expr <- ""
    safe_notify("✅ Custom check saved!", "message")
  })
  
  # ── Custom checks table (PATCH v2.2: stable + no crash on sort/filter) ────────
  custom_checks_df <- reactive({
    if (length(rv$custom_checks) == 0) {
      return(data.frame(
        ID = character(), Name = character(), Severity = character(),
        Created = character(), Source = character(), Expression = character(),
        stringsAsFactors = FALSE
      ))
    }
    do.call(rbind, lapply(rv$custom_checks, function(x) {
      data.frame(
        ID = x$check_id %||% "",
        Name = x$check_name %||% x$description %||% "",
        Severity = x$severity %||% "Medium",
        Created = x$created %||% "",
        Source = x$source %||% "Manual",
        Expression = x$expression_raw %||% "",
        stringsAsFactors = FALSE
      )
    }))
  })
  
  output$dt_custom_checks <- renderDT({
    df <- custom_checks_df()
    datatable(
      df,
      selection = "single",
      options = list(
        dom = "tip",
        pageLength = 6,
        scrollX = TRUE,
        ordering = FALSE,     # key fix: stable selection => no index mismatch crash
        autoWidth = TRUE
      ),
      rownames = FALSE,
      class = "compact stripe"
    )
  })
  
  get_cc_id <- function() {
    sel <- input$dt_custom_checks_rows_selected
    if (is.null(sel) || !length(sel)) return(NULL)
    df <- custom_checks_df()
    if (nrow(df) == 0) return(NULL)
    rid <- sel[1]
    if (is.na(rid) || rid < 1 || rid > nrow(df)) return(NULL)
    df$ID[rid]
  }
  
  get_cc_idx_by_id <- function(id) {
    if (is.null(id) || !nzchar(id)) return(NULL)
    ids <- vapply(rv$custom_checks, function(x) x$check_id %||% "", character(1))
    w <- which(ids == id)
    if (!length(w)) return(NULL)
    w[1]
  }
  
  observeEvent(input$cc_load, {
    id <- get_cc_id()
    idx <- get_cc_idx_by_id(id)
    req(!is.null(idx))
    cc <- rv$custom_checks[[idx]]
    
    updateTextInput(session, "cb_name", value = cc$check_id %||% "")
    updateTextInput(session, "cb_desc", value = cc$description %||% "")
    updateSelectInput(session, "cb_sev", selected = cc$severity %||% "Medium")
    rv$cb_expr <- cc$expression_raw %||% ""
    safe_notify("✅ Loaded into builder.", "message")
  })
  
  observeEvent(input$cc_delete, {
    id <- get_cc_id()
    idx <- get_cc_idx_by_id(id)
    if (is.null(idx)) { safe_notify("Select a custom check first.", "warning"); return() }
    rv$custom_checks <- rv$custom_checks[-idx]
    safe_notify("🗑️ Removed.", "message")
  })
  
  observeEvent(input$cc_edit, {
    id <- get_cc_id()
    idx <- get_cc_idx_by_id(id)
    if (is.null(idx)) { safe_notify("Select a custom check first.", "warning"); return() }
    cc <- rv$custom_checks[[idx]]
    rv$cc_edit_id <- cc$check_id
    
    showModal(modalDialog(
      title = paste0("Edit Custom Check: ", cc$check_id),
      textInput("cc_edit_desc", "Name / Description", value = cc$description %||% ""),
      selectInput("cc_edit_sev", "Severity", c("Low","Medium","High","Critical"),
                  selected = cc$severity %||% "Medium"),
      textareaInput("cc_edit_expr", "Expression (TRUE = issue)", value = cc$expression_raw %||% "",
                    width = "100%", rows = 6),
      footer = tagList(modalButton("Cancel"), actionButton("cc_edit_save", "Save", class = "btn-odqa btn-odqa-primary")),
      easyClose = TRUE
    ))
  })
  
  observeEvent(input$cc_edit_save, {
    req(rv$cc_edit_id)
    id <- rv$cc_edit_id
    idx <- get_cc_idx_by_id(id)
    if (is.null(idx)) { removeModal(); return() }
    
    desc <- trimws(input$cc_edit_desc %||% "")
    sev  <- input$cc_edit_sev %||% "Medium"
    expr <- trimws(input$cc_edit_expr %||% "")
    
    if (!nzchar(desc)) { safe_notify("Description cannot be empty.", "warning"); return() }
    if (!nzchar(expr)) { safe_notify("Expression cannot be empty.", "warning"); return() }
    
    # ── [SEC-5] Security-grade expression validation ──────────────────────────
    sec_blacklist_rx <- "(system|exec|shell|pipe|download|source|\\beval\\b|\\bparse\\b|assign|\\brm\\(|file\\.|readLines|writeLines|unlink|library|require|install|Sys\\.|proc\\.time|options\\(|setwd|getwd|\\bdo\\.call\\b|environment|globalenv|baseenv|new\\.env)"
    if (grepl(sec_blacklist_rx, expr, ignore.case = TRUE, perl = TRUE)) {
      safe_notify("Expression contains forbidden function calls (security policy).", "error")
      return()
    }
    
    parsed <- tryCatch(rlang::parse_expr(expr), error = function(e) e)
    if (inherits(parsed, "error")) { safe_notify(paste("Invalid expression:", parsed$message), "error"); return() }
    
    # runtime sanity check on small data slice if available
    df_test <- (rv$mapped %||% rv$raw)
    if (!is.null(df_test) && nrow(df_test) > 0) {
      sl <- df_test[seq_len(min(50, nrow(df_test))), , drop = FALSE]
      ok <- tryCatch(eval(parsed, envir = sl), error = function(e) e)
      if (inherits(ok, "error") || !(is.logical(ok) || is.numeric(ok) || is.integer(ok))) {
        safe_notify("Expression must evaluate to a logical vector (TRUE = issue).", "error")
        return()
      }
    }
    
    cc <- rv$custom_checks[[idx]]
    cc$description <- desc
    cc$severity <- sev
    cc$expression_raw <- expr
    rv$custom_checks[[idx]] <- cc
    
    removeModal()
    safe_notify("✅ Updated.", "message")
  })
  
  
  get_cc_idx <- function() {
    sel <- input$dt_custom_checks_rows_selected
    if (is.null(sel) || length(sel) == 0) return(NULL)
    as.integer(sel[1])
  }
  
  observeEvent(input$cc_load, {
    idx <- get_cc_idx()
    req(!is.null(idx), idx >= 1, idx <= length(rv$custom_checks))
    cc <- rv$custom_checks[[idx]]
    
    updateTextInput(session, "cb_name", value = cc$check_id %||% "")
    updateTextInput(session, "cb_desc", value = cc$description %||% "")
    updateSelectInput(session, "cb_sev", selected = cc$severity %||% "Medium")
    
    rv$conditions <- rv$conditions[0, ]
    rv$cb_expr <- cc$expression_raw %||% ""
    
    safe_notify("Loaded selected check into the builder.", "message")
  })
  
  observeEvent(input$cc_edit, {
    idx <- get_cc_idx()
    req(!is.null(idx), idx >= 1, idx <= length(rv$custom_checks))
    cc <- rv$custom_checks[[idx]]
    
    showModal(modalDialog(
      title = paste0("Edit check: ", cc$check_id),
      textInput("cc_edit_desc", "Description", value = cc$description %||% "", width="100%"),
      selectInput("cc_edit_sev", "Severity", c("Low","Medium","High","Critical"),
                  selected = cc$severity %||% "Medium", width="100%"),
      textareaInput("cc_edit_expr", "Expression (TRUE = issue)", value = cc$expression_raw %||% "",
                    width="100%", rows=8),
      footer = tagList(modalButton("Cancel"),
                       actionButton("cc_edit_save", "Save changes", class="btn-odqa btn-odqa-primary")),
      easyClose = TRUE
    ))
    rv$cc_edit_idx <- idx
  })
  
  observeEvent(input$cc_edit_save, {
    idx <- rv$cc_edit_idx %||% NULL
    req(!is.null(idx), idx >= 1, idx <= length(rv$custom_checks))
    req(input$cc_edit_expr)
    
    cc <- rv$custom_checks[[idx]]
    cc$description <- input$cc_edit_desc %||% cc$description
    cc$severity <- input$cc_edit_sev %||% cc$severity
    cc$expression_raw <- trimws(input$cc_edit_expr)
    cc$updated <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    rv$custom_checks[[idx]] <- cc
    
    removeModal()
    safe_notify("✅ Check updated.", "message")
  })
  
  observeEvent(input$cc_delete, {
    idx <- get_cc_idx()
    req(!is.null(idx), idx >= 1, idx <= length(rv$custom_checks))
    rv$custom_checks <- rv$custom_checks[-idx]
    safe_notify("🗑️ Removed selected check.", "message")
  })
  
  
  # ── JSON Import (V0.1: robust, validated, crash-proof) ─────────────────────
  observeEvent(input$json_import, {
    req(input$json_import)
    tryCatch({
      fpath <- input$json_import$datapath
      
      # ═══════════════════════════════════════════════════════════════════
      # STAGE 1: File existence and size validation
      # ═══════════════════════════════════════════════════════════════════
      if (!file.exists(fpath)) {
        safe_notify("\u274C File not found.", "error"); return()
      }
      fsize <- file.info(fpath)$size
      if (is.na(fsize) || fsize == 0) {
        safe_notify("\u274C File is empty.", "error"); return()
      }
      if (fsize > 50 * 1024^2) {
        safe_notify("\u274C File too large (>50 MB).", "error"); return()
      }
      
      # ═══════════════════════════════════════════════════════════════════
      # STAGE 2: Read raw text with encoding safety
      # ═══════════════════════════════════════════════════════════════════
      raw_text <- tryCatch(
        readLines(fpath, warn = FALSE, encoding = "UTF-8"),
        error = function(e) NULL
      )
      if (is.null(raw_text) || length(raw_text) == 0) {
        safe_notify("\u274C Cannot read file contents.", "error"); return()
      }
      json_str <- paste(raw_text, collapse = "\n")
      
      # Strip BOM if present
      json_str <- sub("^\uFEFF", "", json_str)
      
      # ═══════════════════════════════════════════════════════════════════
      # STAGE 3: JSON syntax validation
      # ═══════════════════════════════════════════════════════════════════
      valid_json <- tryCatch(jsonlite::validate(json_str), error = function(e) FALSE)
      if (!isTRUE(valid_json)) {
        safe_notify("\u274C Invalid JSON syntax. Please check file format.", "error"); return()
      }
      
      # ═══════════════════════════════════════════════════════════════════
      # STAGE 4: Multi-strategy JSON parsing
      # ═══════════════════════════════════════════════════════════════════
      lst <- NULL
      
      # Strategy A: Parse without simplification (preserves nested structures)
      lst <- tryCatch(
        jsonlite::fromJSON(json_str, simplifyVector = FALSE, simplifyDataFrame = FALSE),
        error = function(e) NULL
      )
      
      # Strategy B: If A fails, try with simplification
      if (is.null(lst)) {
        lst <- tryCatch(
          jsonlite::fromJSON(json_str, simplifyVector = TRUE),
          error = function(e) NULL
        )
      }
      
      if (is.null(lst)) {
        safe_notify("\u274C Could not parse JSON structure.", "error"); return()
      }
      
      # ═══════════════════════════════════════════════════════════════════
      # STAGE 5: Robust check extraction from any structure
      # ═══════════════════════════════════════════════════════════════════
      extract_checks <- function(obj) {
        out <- list()
        
        if (is.data.frame(obj)) {
          # data.frame: each row is a check
          for (i in seq_len(nrow(obj))) {
            row_list <- as.list(obj[i, , drop = FALSE])
            # Flatten any list columns to character
            row_list <- lapply(row_list, function(v) {
              if (is.list(v)) paste(unlist(v), collapse = "; ") else as.character(v)
            })
            out <- c(out, list(row_list))
          }
        } else if (is.list(obj) && !is.null(names(obj))) {
          # Named list: could be single check or envelope
          if ("check_id" %in% names(obj) || "expression_raw" %in% names(obj)) {
            # Single check object
            out <- list(obj)
          } else if ("checks" %in% names(obj) && is.list(obj$checks)) {
            # Envelope with "checks" key
            out <- extract_checks(obj$checks)
          } else {
            # Try treating each element as a check
            for (item in obj) {
              if (is.list(item)) out <- c(out, extract_checks(item))
            }
          }
        } else if (is.list(obj) && is.null(names(obj))) {
          # Unnamed list (array)
          for (item in obj) {
            if (is.list(item)) {
              out <- c(out, extract_checks(item))
            }
          }
        }
        out
      }
      
      checks_to_add <- extract_checks(lst)
      
      if (length(checks_to_add) == 0) {
        safe_notify("\u26A0\uFE0F No valid checks found in file.", "warning"); return()
      }
      
      # ═══════════════════════════════════════════════════════════════════
      # STAGE 6: Field validation & sanitization
      # ═══════════════════════════════════════════════════════════════════
      safe_char <- function(x, fallback = "") {
        if (is.null(x) || length(x) == 0) return(fallback)
        val <- as.character(x[[1]])
        if (is.na(val) || !nzchar(trimws(val))) return(fallback)
        trimws(val)
      }
      
      valid_checks <- list()
      skipped <- 0L
      parse_errors <- 0L
      
      existing_ids <- vapply(rv$custom_checks, function(x) {
        safe_char(x$check_id, "")
      }, character(1))
      
      for (cc in checks_to_add) {
        # Ensure all fields are character (prevents type coercion crashes)
        cc <- lapply(cc, function(v) {
          if (is.list(v)) paste(unlist(v), collapse = "; ")
          else if (is.null(v)) ""
          else as.character(v)
        })
        
        # Auto-generate check_id if missing
        cid <- safe_char(cc$check_id, "")
        if (!nzchar(cid)) {
          cid <- paste0("imp_", format(Sys.time(), "%H%M%S"), "_",
                        sample(1000:9999, 1))
        }
        cc$check_id <- cid
        
        # Sanitize required fields
        cc$description <- safe_char(cc$description,
                                    safe_char(cc$check_name, "Imported check"))
        cc$severity <- safe_char(cc$severity, "Medium")
        
        # Validate severity value
        valid_sevs <- c("Low", "Medium", "High", "Critical")
        if (!cc$severity %in% valid_sevs) {
          cc$severity <- "Medium"
        }
        
        # Validate expression_raw if present
        expr_raw <- safe_char(cc$expression_raw, "")
        if (nzchar(expr_raw)) {
          expr_ok <- tryCatch({
            parse(text = expr_raw, keep.source = FALSE)
            TRUE
          }, error = function(e) FALSE)
          if (!expr_ok) {
            parse_errors <- parse_errors + 1L
            cc$expression_raw <- paste0("# PARSE ERROR - review: ", expr_raw)
          }
        }
        
        # Ensure created timestamp
        if (!nzchar(safe_char(cc$created, ""))) {
          cc$created <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
        }
        
        # Deduplicate
        if (cid %in% existing_ids) {
          skipped <- skipped + 1L
          next
        }
        
        existing_ids <- c(existing_ids, cid)
        valid_checks <- c(valid_checks, list(cc))
      }
      
      # ═══════════════════════════════════════════════════════════════════
      # STAGE 7: Append and notify
      # ═══════════════════════════════════════════════════════════════════
      if (length(valid_checks) > 0) {
        rv$custom_checks <- c(rv$custom_checks, valid_checks)
      }
      
      msg <- paste0("\u2705 Imported ", length(valid_checks), " check(s)")
      if (skipped > 0) msg <- paste0(msg, " | ", skipped, " duplicates skipped")
      if (parse_errors > 0) msg <- paste0(msg, " | ", parse_errors, " expression parse warnings")
      safe_notify(msg, "message")
      
    }, error = function(e) {
      safe_notify(paste("\u274C Import failed:", e$message), "error")
    })
  })
  
  # ── JSON Export (V0.1: with metadata envelope) ──────────────────────────────
  output$json_export <- downloadHandler(
    filename = function() paste0("odqa_checks_", format(Sys.time(), "%Y%m%d_%H%M"), ".json"),
    content = function(file) {
      tryCatch({
        # Build export with metadata
        export_list <- lapply(rv$custom_checks, function(cc) {
          list(
            check_id       = cc$check_id %||% "unknown",
            description    = cc$description %||% "",
            severity       = cc$severity %||% "Medium",
            expression_raw = cc$expression_raw %||% "",
            created        = cc$created %||% "",
            exported_at    = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
            tool_version   = "Open DQA V0.1"
          )
        })
        jsonlite::write_json(export_list, file, pretty = TRUE, auto_unbox = TRUE)
      }, error = function(e) {
        # Fallback: write error info
        jsonlite::write_json(
          list(error = e$message, timestamp = as.character(Sys.time())),
          file, pretty = TRUE, auto_unbox = TRUE)
        safe_notify(paste("\u26A0\uFE0F Export partially failed:", e$message), "warning")
      })
    })
  
  # ── Run Checks Engine (FAST v2) ──────────────────────────────────────────────
  # Key speed-ups:
  #   - Precompute cleaned columns once (dates, icd/ops normalized strings, gender/age, anamnese lower)
  #   - Vectorized grepl over 1M rows (no per-row token splitting)
  #   - Collect results in a list + rbindlist at end (avoid repeated rbind)
  #   - Pattern checks use "token-start" boundary (^|;) on delimiter-normalized strings
  
  observeEvent(input$btn_run, {
    
    req(rv$mapped)
    df  <- rv$mapped
    n   <- nrow(df)
    sel <- get_selected_checks()
    
    t_start <- proc.time()
    
    has <- function(col) col %in% names(df)
    
    # -----------------------------
    # FAST helpers
    # -----------------------------
    trim_chr <- function(x) {
      x <- as.character(x)
      x[is.na(x)] <- ""
      trimws(x)
    }
    is_blank <- function(x) {
      x <- trim_chr(x)
      !nzchar(x)
    }
    safe_lower <- function(x) {
      x <- trim_chr(x)
      tolower(x)
    }
    
    as_date_safe <- function(x) {
      if (inherits(x, "Date")) return(x)
      if (inherits(x, "POSIXt")) return(as.Date(x))
      x0 <- trim_chr(x)
      out <- suppressWarnings(as.Date(x0))
      if (all(is.na(out) & nzchar(x0))) {
        out2 <- suppressWarnings(as.Date(x0, format = "%Y-%m-%d"))
        out3 <- suppressWarnings(as.Date(x0, format = "%d.%m.%Y"))
        out4 <- suppressWarnings(as.Date(x0, format = "%d/%m/%Y"))
        out  <- out2
        out[is.na(out)] <- out3[is.na(out)]
        out[is.na(out)] <- out4[is.na(out)]
      }
      out
    }
    
    # Normalize multi-code fields to a single delimiter-separated string:
    #   - uppercase
    #   - remove whitespace
    #   - delimiters [,;|/ and any whitespace] -> ;
    norm_code_cell <- function(x) {
      x <- trim_chr(x)
      x <- toupper(x)
      x <- gsub("\\s+", "", x, perl = TRUE)
      x <- gsub("[,|/]+", ";", x, perl = TRUE)
      x <- gsub(";{2,}", ";", x, perl = TRUE)
      x <- gsub("^;|;$", "", x, perl = TRUE)
      x
    }
    
    # Token start boundary: token begins at start or after ';'
    # Use prefix-like patterns (e.g. "C61" or "H35\\.3" etc.)
    has_token_prefix <- function(code_norm, token_prefix_regex, ignore.case = FALSE) {
      if (length(code_norm) == 0) return(logical(0))
      # boundary ensures match only at token start (not inside a token)
      grepl(paste0("(^|;)", token_prefix_regex), code_norm, perl = TRUE, ignore.case = ignore.case)
    }
    
    # Any token matches general regex at token start (still boundary anchored)
    has_token_start_regex <- function(code_norm, token_start_regex, ignore.case = TRUE) {
      grepl(paste0("(^|;)", token_start_regex), code_norm, perl = TRUE, ignore.case = ignore.case)
    }
    
    # Validate that ALL tokens in a cell match pattern by "remove-valid-tokens" trick:
    # 1) normalize delimiters to ';'
    # 2) strip all valid tokens from the string
    # 3) strip delimiters
    # 4) if anything remains -> invalid token exists
    any_invalid_token <- function(code_norm, token_regex) {
      # Checks whether at least one token in a ';'-normalized code string
      # does NOT fully match token_regex (token-level validation, no partial matches).
      #
      # token_regex must describe ONE FULL TOKEN (without (^|;) ... ($|;)).
      #
      # Examples:
      #   ICD token: "[A-Z][0-9]{2}(\\.[0-9]{1,2})?"
      #   OPS token: "[0-9]-[0-9]{2,3}(\\.[0-9A-Z]{1,4})?[LRB]?"
      
      nonempty <- !is.na(code_norm) & nzchar(code_norm)
      if (!any(nonempty)) return(rep(FALSE, length(code_norm)))
      
      # Match FULL tokens only (start or ';' boundary, and must end before ';' or end-of-string).
      re <- paste0("(^|;)", token_regex, "(?=;|$)")
      
      tmp <- code_norm
      tmp[!nonempty] <- ""
      
      # Remove valid tokens but keep the leading delimiter (\\1) to preserve ';' structure
      tmp <- gsub(re, "\\1", tmp, perl = TRUE)
      
      # Remove remaining delimiters; if anything remains => invalid chunk existed
      tmp <- gsub(";", "", tmp, perl = TRUE)
      nonempty & nzchar(tmp)
    }
    
    
    norm_gender <- function(g) {
      g0 <- safe_lower(g)
      out <- rep(NA_character_, length(g0))
      out[g0 %in% c("m","male","mann","man","masculin","masculine")] <- "male"
      out[g0 %in% c("w","f","female","frau","woman","feminin","feminine")] <- "female"
      out
    }
    
    # -----------------------------
    # Precompute columns once
    # -----------------------------
    adm  <- if (has("admission_date")) as_date_safe(df$admission_date) else NULL
    dis  <- if (has("discharge_date")) as_date_safe(df$discharge_date) else NULL
    bdat <- if (has("birth_date"))     as_date_safe(df$birth_date)     else NULL
    
    icd_raw <- if (has("icd")) df$icd else NULL
    ops_raw <- if (has("ops")) df$ops else NULL
    
    icd_norm_all <- if (!is.null(icd_raw)) norm_code_cell(icd_raw) else NULL
    ops_norm_all <- if (!is.null(ops_raw)) norm_code_cell(ops_raw) else NULL
    
    has_icd_any <- if (!is.null(icd_norm_all)) nzchar(icd_norm_all) else rep(FALSE, n)
    has_ops_any <- if (!is.null(ops_norm_all)) nzchar(ops_norm_all) else rep(FALSE, n)
    
    anam <- if (has("anamnese")) safe_lower(df$anamnese %||% "") else NULL
    age  <- if (has("age")) suppressWarnings(as.numeric(df$age)) else NULL
    gnd  <- if (has("gender")) norm_gender(df$gender) else NULL
    
    pid_col <- if (has("patient_id")) as.character(df$patient_id) else NULL
    
    # for speed: local function to append issues
    res_list <- list()
    k <- 0L
    add_issue <- function(flagged, cid, cl, sev) {
      if (length(flagged) == 0) return(invisible(NULL))
      k <<- k + 1L
      res_list[[k]] <<- data.frame(
        row = flagged,
        check_id = cid,
        issue = cl$w,
        severity = sev,
        patient_id = if (!is.null(pid_col)) pid_col[flagged] else rep(NA_character_, length(flagged)),
        stringsAsFactors = FALSE
      )
      invisible(NULL)
    }
    
    # -----------------------------
    # Run checks
    # -----------------------------
    with_waiter({
      
      for (cid in sel) {
        cl <- CL[[cid]]
        if (is.null(cl)) next
        needed <- cl$n
        if (!all(vapply(needed, has, logical(1)))) next
        sev <- cl$sev
        
        flagged <- tryCatch({
          
          switch(cid,
                 
                 # -----------------
                 # Category 1
                 # -----------------
                 "cat1_1" = {
                   which(!is.na(adm) & !has_icd_any)
                 },
                 
                 "cat1_2" = {
                   # OPS missing for >10% 'surgery' mentions
                   if (is.null(anam) || is.null(ops_norm_all)) return(integer(0))
                   surg_idx <- which(grepl("surg|chirurg", anam, perl = TRUE))
                   if (length(surg_idx) == 0) return(integer(0))
                   miss <- !nzchar(ops_norm_all[surg_idx])
                   prop_miss <- mean(miss)
                   if (!is.finite(prop_miss) || prop_miss <= 0.10) return(integer(0))
                   surg_idx[miss]
                 },
                 
                 "cat1_3" = {
                   if (is.null(anam) || is.null(icd_norm_all)) return(integer(0))
                   idx <- which(grepl("diab", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   ok <- has_token_prefix(icd_norm_all[idx], "E1[0-4]", ignore.case = TRUE)
                   idx[!ok]
                 },
                 
                 "cat1_4" = {
                   if (is.null(anam) || is.null(icd_norm_all)) return(integer(0))
                   idx <- which(grepl("heart|herz|cardio|kardio", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   ok <- has_token_prefix(icd_norm_all[idx], "I", ignore.case = TRUE)
                   idx[!ok]
                 },
                 
                 "cat1_5" = {
                   if (is.null(anam) || is.null(ops_norm_all)) return(integer(0))
                   idx <- which(grepl("chemo|chemotherap", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   idx[!nzchar(ops_norm_all[idx])]
                 },
                 
                 "cat1_6" = {
                   if (is.null(anam) || is.null(icd_norm_all)) return(integer(0))
                   idx <- which(grepl("copd|obstruk|obstruct", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   ok <- has_token_prefix(icd_norm_all[idx], "J44", ignore.case = TRUE)
                   idx[!ok]
                 },
                 
                 "cat1_7" = {
                   if (is.null(anam) || is.null(ops_norm_all)) return(integer(0))
                   idx <- which(grepl("radiol|r[oö]ntgen|roentgen|\\bct\\b|\\bmrt\\b|\\bmri\\b", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   idx[!nzchar(ops_norm_all[idx])]
                 },
                 
                 "cat1_8" = {
                   if (is.null(anam) || is.null(icd_norm_all)) return(integer(0))
                   idx <- which(grepl("allerg", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   ok <- has_token_prefix(icd_norm_all[idx], "T78", ignore.case = TRUE)
                   idx[!ok]
                 },
                 
                 "cat1_9" = {
                   if (is.null(anam) || is.null(ops_norm_all)) return(integer(0))
                   idx <- which(grepl("dialys|hemodial|h[aä]modial|peritoneal", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   idx[!nzchar(ops_norm_all[idx])]
                 },
                 
                 "cat1_10" = {
                   if (is.null(anam) || is.null(icd_norm_all)) return(integer(0))
                   idx <- which(grepl("hyperton|hypertens|blutdruck", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   ok <- has_token_prefix(icd_norm_all[idx], "I10", ignore.case = TRUE)
                   idx[!ok]
                 },
                 
                 "cat1_11" = {
                   if (is.null(anam) || is.null(ops_norm_all)) return(integer(0))
                   idx <- which(grepl("endoskop|endoscop|gastroskop|koloskop|coloskop", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   idx[!nzchar(ops_norm_all[idx])]
                 },
                 
                 "cat1_12" = {
                   if (is.null(anam) || is.null(icd_norm_all)) return(integer(0))
                   idx <- which(grepl("stroke|schlaganfall|apoplex|hirninfarkt", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   ok <- has_token_prefix(icd_norm_all[idx], "(I63|I64)", ignore.case = TRUE)
                   idx[!ok]
                 },
                 
                 "cat1_13" = {
                   if (is.null(anam) || is.null(icd_norm_all)) return(integer(0))
                   idx <- which(grepl("infekt|infection|sepsis|septisch", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   ok <- has_token_prefix(icd_norm_all[idx], "B", ignore.case = TRUE)
                   idx[!ok]
                 },
                 
                 "cat1_14" = {
                   if (is.null(anam) || is.null(ops_norm_all)) return(integer(0))
                   idx <- which(grepl("prothese|prosthe|implant", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   idx[!nzchar(ops_norm_all[idx])]
                 },
                 
                 "cat1_15" = {
                   if (is.null(anam) || is.null(icd_norm_all)) return(integer(0))
                   idx <- which(grepl("depress", anam, perl = TRUE))
                   if (length(idx) == 0) return(integer(0))
                   ok <- has_token_prefix(icd_norm_all[idx], "F3[23]", ignore.case = TRUE)
                   idx[!ok]
                 },
                 
                 "cat1_16" = {
                   which(!is.na(adm) & !has_icd_any & !has_ops_any)
                 },
                 
                 # -----------------
                 # Category 2 (age/gender plausibility)
                 # -----------------
                 "cat2_1"  = if (!is.null(age) && !is.null(icd_norm_all)) which(age < 15  & has_token_prefix(icd_norm_all, "C61", ignore.case = TRUE)) else integer(0),
                 "cat2_2"  = if (!is.null(age) && !is.null(icd_norm_all)) which(age < 30  & has_token_prefix(icd_norm_all, "(F00|G30)", ignore.case = TRUE)) else integer(0),
                 "cat2_3"  = if (!is.null(age) && !is.null(icd_norm_all)) which(age > 70  & has_token_prefix(icd_norm_all, "F8[0-9]", ignore.case = TRUE)) else integer(0),
                 "cat2_4"  = if (!is.null(age) && !is.null(icd_norm_all)) which(age < 18  & has_token_prefix(icd_norm_all, "M8[01]", ignore.case = TRUE)) else integer(0),
                 "cat2_5"  = if (!is.null(age) && !is.null(icd_norm_all)) which(age > 60  & has_token_prefix(icd_norm_all, "B05", ignore.case = TRUE)) else integer(0),
                 "cat2_6"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male" & has_token_prefix(icd_norm_all, "O(6[0-9]|7[0-5])", ignore.case = TRUE)) else integer(0),
                 "cat2_7"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male" & has_token_prefix(icd_norm_all, "N95", ignore.case = TRUE)) else integer(0),
                 "cat2_8"  = if (!is.null(age) && !is.null(icd_norm_all)) which(age < 1   & has_token_prefix(icd_norm_all, "L70", ignore.case = TRUE)) else integer(0),
                 "cat2_9"  = if (!is.null(age) && !is.null(icd_norm_all)) which(age < 30  & has_token_prefix(icd_norm_all, "H35\\.3", ignore.case = TRUE)) else integer(0),
                 "cat2_10" = if (!is.null(age) && !is.null(icd_norm_all)) which(age > 21  & has_token_prefix(icd_norm_all, "G80", ignore.case = TRUE)) else integer(0),
                 "cat2_11" = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male" & has_token_prefix(icd_norm_all, "O14", ignore.case = TRUE)) else integer(0),
                 "cat2_12" = if (!is.null(age) && !is.null(icd_norm_all)) which(age > 70  & has_token_prefix(icd_norm_all, "M08", ignore.case = TRUE)) else integer(0),
                 "cat2_13" = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "female" & has_token_prefix(icd_norm_all, "E29", ignore.case = TRUE)) else integer(0),
                 "cat2_14" = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "female" & has_token_prefix(icd_norm_all, "C62", ignore.case = TRUE)) else integer(0),
                 "cat2_15" = if (!is.null(age) && !is.null(icd_norm_all)) which(age > 60  & has_token_prefix(icd_norm_all, "E30\\.0", ignore.case = TRUE)) else integer(0),
                 
                 # -----------------
                 # Category 3 (gender contradictions)
                 # -----------------
                 "cat3_1"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male"   & has_token_prefix(icd_norm_all, "N83", ignore.case = TRUE)) else integer(0),
                 "cat3_2"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "female" & has_token_prefix(icd_norm_all, "N41", ignore.case = TRUE)) else integer(0),
                 "cat3_3"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male"   & has_token_prefix(icd_norm_all, "O",   ignore.case = TRUE)) else integer(0),
                 "cat3_4"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "female" & has_token_prefix(icd_norm_all, "C62", ignore.case = TRUE)) else integer(0),
                 "cat3_5"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male"   & has_token_prefix(icd_norm_all, "N80", ignore.case = TRUE)) else integer(0),
                 "cat3_6"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "female" & has_token_prefix(icd_norm_all, "N52", ignore.case = TRUE)) else integer(0),
                 "cat3_7"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male"   & has_token_prefix(icd_norm_all, "C53", ignore.case = TRUE)) else integer(0),
                 "cat3_8"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "female" & has_token_prefix(icd_norm_all, "E28\\.1", ignore.case = TRUE)) else integer(0),
                 "cat3_9"  = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male"   & has_token_prefix(icd_norm_all, "N9[23]", ignore.case = TRUE)) else integer(0),
                 "cat3_10" = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male"   & has_token_prefix(icd_norm_all, "C50", ignore.case = TRUE)) else integer(0),
                 "cat3_11" = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "female" & has_token_prefix(icd_norm_all, "N47", ignore.case = TRUE)) else integer(0),
                 "cat3_12" = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male"   & has_token_prefix(icd_norm_all, "N76", ignore.case = TRUE)) else integer(0),
                 "cat3_13" = {
                   # Perinatal ICD codes (P*) in male patient (note: no age context available here)
                   if (is.null(gnd) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     which(gnd == "male" & grepl("(^|;)P[0-9]{2}(\\.|$|;)", icd_norm_all, perl = TRUE, ignore.case = TRUE))
                   }
                 },
                 "cat3_14" = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "female" & has_token_prefix(icd_norm_all, "Q53", ignore.case = TRUE)) else integer(0),
                 "cat3_15" = if (!is.null(gnd) && !is.null(icd_norm_all)) which(gnd == "male"   & has_token_prefix(icd_norm_all, "O21", ignore.case = TRUE)) else integer(0),
                 
                 # -----------------
                 # Category 4 (temporal / duplicates)
                 # -----------------
                 "cat4_2" = {
                   if (is.null(adm) || is.null(dis)) {
                     integer(0)
                   } else {
                     which(!is.na(adm) & !is.na(dis) & dis < adm)
                   }
                 },
                 
                 "cat4_4" = {
                   if (!has("patient_id") || is.null(adm)) {
                     integer(0)
                   } else {
                     pid <- trim_chr(df$patient_id)
                     key <- paste0(pid, "||", as.character(adm))
                     dups <- duplicated(key) | duplicated(key, fromLast = TRUE)
                     which(!is.na(adm) & nzchar(pid) & dups)
                   }
                 },
                 
                 "cat4_6" = {
                   if (is.null(adm)) {
                     integer(0)
                   } else {
                     which(!is.na(adm) & adm > Sys.Date())
                   }
                 },
                 
                 "cat4_8" = {
                   # Same-day discharge with "complex" OPS:
                   # heuristically treat OPS chapter 5-* (operations) and 8-5..8-9 (therapeutic/complex)
                   if (is.null(adm) || is.null(dis) || is.null(ops_norm_all)) {
                     integer(0)
                   } else {
                     complex_ops <- grepl("(^|;)(5-|8-[5-9])", ops_norm_all, perl = TRUE)
                     which(!is.na(adm) & !is.na(dis) & adm == dis & complex_ops)
                   }
                 },
                 
                 "cat4_12" = {
                   if (is.null(adm) || is.null(bdat)) {
                     integer(0)
                   } else {
                     which(!is.na(adm) & !is.na(bdat) & adm < bdat)
                   }
                 },
                 
                 "cat4_15" = {
                   if (is.null(adm) || is.null(dis)) {
                     integer(0)
                   } else {
                     which(!is.na(adm) & !is.na(dis) & dis < adm)
                   }
                 },
                 
                 # -----------------
                 # Category 5 (OPS ↔ ICD consistency)
                 # NOTE: use has_token_prefix() so prefixes like 5-74* or 5-68* are matched correctly.
                 # -----------------
                 "cat5_1" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Appendectomy OPS (5-470*) without Appendicitis ICD (K35–K37)
                     has_ops <- has_token_prefix(ops_norm_all, "5-470")
                     has_icd <- has_token_prefix(icd_norm_all, "K3[5-7]")
                     which(has_ops & !has_icd)
                   }
                 },
                 
                 "cat5_2" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Knee endoprosthesis (5-822* / 5-823*) without Gonarthrosis ICD (M17*)
                     has_ops <- has_token_prefix(ops_norm_all, "(5-822|5-823)")
                     has_icd <- has_token_prefix(icd_norm_all, "M17")
                     which(has_ops & !has_icd)
                   }
                 },
                 
                 "cat5_3" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Chemo OPS (8-54*) without Cancer-related ICD (C* or D0–D4*)
                     has_ops <- has_token_prefix(ops_norm_all, "8-54")
                     has_ca  <- has_token_prefix(icd_norm_all, "(C|D[0-4])")
                     which(has_ops & !has_ca)
                   }
                 },
                 
                 "cat5_4" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Heart catheterization (OPS 1-27[3-7]*) without I-chapter ICD (I*)
                     has_ops <- has_token_prefix(ops_norm_all, "1-27[3-7]")
                     has_i   <- has_token_prefix(icd_norm_all, "I")
                     which(has_ops & !has_i)
                   }
                 },
                 
                 "cat5_5" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Dialysis (8-85*) without CKD ICD (N18*)
                     has_ops <- has_token_prefix(ops_norm_all, "8-85")
                     has_n18 <- has_token_prefix(icd_norm_all, "N18")
                     which(has_ops & !has_n18)
                   }
                 },
                 
                 "cat5_6" = {
                   if (is.null(gnd) || is.null(ops_norm_all)) {
                     integer(0)
                   } else {
                     # C-section OPS (5-74*) in male patient
                     has_ops <- has_token_prefix(ops_norm_all, "5-74")
                     which(gnd == "male" & has_ops)
                   }
                 },
                 
                 "cat5_7" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Cataract surgery OPS (5-144*) without Cataract ICD (H25/H26)
                     has_ops <- has_token_prefix(ops_norm_all, "5-144")
                     has_icd <- has_token_prefix(icd_norm_all, "H2[5-6]")
                     which(has_ops & !has_icd)
                   }
                 },
                 
                 "cat5_8" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Bariatric / gastric bypass-like OPS (5-447* / 5-448*) without Obesity ICD (E66)
                     has_ops <- has_token_prefix(ops_norm_all, "(5-447|5-448)")
                     has_icd <- has_token_prefix(icd_norm_all, "E66")
                     which(has_ops & !has_icd)
                   }
                 },
                 
                 "cat5_9" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Hysterectomy OPS (5-68*) without typical GYN ICD (broad heuristic)
                     has_ops <- has_token_prefix(ops_norm_all, "5-68")
                     has_gyn <- has_token_prefix(icd_norm_all, "(N7[0-9]|N8[0-9]|N9[0-9]|D2[5-6]|C5[3-8])")
                     which(has_ops & !has_gyn)
                   }
                 },
                 
                 "cat5_10" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Blood transfusion OPS (8-800*) without Anemia ICD (D50–D64)
                     has_ops  <- has_token_prefix(ops_norm_all, "8-800")
                     has_anem <- has_token_prefix(icd_norm_all, "(D5[0-9]|D6[0-4])")
                     which(has_ops & !has_anem)
                   }
                 },
                 
                 "cat5_11" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Knee arthroscopy OPS (5-812*) without knee-related ICD (heuristic)
                     has_ops  <- has_token_prefix(ops_norm_all, "5-812")
                     has_knee <- has_token_prefix(icd_norm_all, "(M17|M22|M23|M25\\.56|S82|S83)")
                     which(has_ops & !has_knee)
                   }
                 },
                 
                 "cat5_12" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # CT (3-2xx*) or MRI (3-8xx*) OPS without ANY ICD documented
                     has_img <- has_token_prefix(ops_norm_all, "(3-2[0-9]{2}|3-8[0-9]{2})")
                     which(has_img & !nzchar(icd_norm_all))
                   }
                 },
                 
                 "cat5_13" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Skin graft / skin reconstruction OPS (5-90*) without wound/burn ICD (heuristic)
                     has_ops <- has_token_prefix(ops_norm_all, "5-90")
                     has_wb  <- has_token_prefix(icd_norm_all, "(S|T2[0-9]|T3[0-2]|L97|L89)")
                     which(has_ops & !has_wb)
                   }
                 },
                 
                 "cat5_14" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Upper GI endoscopy OPS (1-632*) without digestive ICD (K*)
                     has_ops <- has_token_prefix(ops_norm_all, "1-632")
                     has_k   <- has_token_prefix(icd_norm_all, "K")
                     which(has_ops & !has_k)
                   }
                 },
                 
                 "cat5_15" = {
                   if (is.null(ops_norm_all) || is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Pacemaker implantation/replacement OPS (5-377* / 5-378*) without arrhythmia ICD (I44–I49)
                     has_ops <- has_token_prefix(ops_norm_all, "(5-377|5-378)")
                     has_i44_49 <- has_token_prefix(icd_norm_all, "I4[4-9]")
                     which(has_ops & !has_i44_49)
                   }
                 },
                 
                 # -----------------
                 # Category 6 (code integrity)
                 # -----------------
                 "cat6_1" = {
                   if (is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     bad <- any_invalid_token(icd_norm_all, "[A-Z][0-9]{2}(\\.[0-9]{1,2})?")
                     which(bad)
                   }
                 },
                 
                 "cat6_2" = {
                   # OPS looks "retired/unspecific" (heuristic): tokens ending with .x / .y / .9 / .90 / .99
                   if (is.null(ops_norm_all)) {
                     integer(0)
                   } else {
                     which(grepl("(^|;)[0-9]-[0-9]{2,3}\\.(X|Y|9|90|99)(?=;|$)", ops_norm_all, perl = TRUE, ignore.case = TRUE))
                   }
                 },
                 
                 "cat6_3" = {
                   # ICD potential typo (near-miss): token invalid, but becomes valid after common OCR/typo substitutions.
                   if (is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     icd_token_re <- "[A-Z][0-9]{2}(\\.[0-9]{1,2})?"
                     bad_mask <- any_invalid_token(icd_norm_all, icd_token_re) & nzchar(icd_norm_all)
                     cand_idx <- which(bad_mask)
                     if (length(cand_idx) == 0) {
                       integer(0)
                     } else {
                       cand <- icd_norm_all[cand_idx]
                       looks_icd <- function(tok) grepl(paste0("^", icd_token_re, "$"), tok, perl = TRUE)
                       fix_tok <- function(tok) {
                         tok <- toupper(tok)
                         tok <- gsub("[^A-Z0-9\\.]", "", tok, perl = TRUE)
                         if (nchar(tok) < 3) return(tok)
                         first <- substr(tok, 1, 1)
                         rest  <- substr(tok, 2, nchar(tok))
                         rest  <- chartr("OILSZB", "011528", rest) # O->0, I/L->1, S->5, Z->2, B->8
                         tok2  <- paste0(first, rest)
                         gsub("\\.{2,}", ".", tok2, perl = TRUE)
                       }
                       fixable <- vapply(strsplit(cand, ";", fixed = TRUE), function(toks) {
                         any(vapply(toks, function(tok) {
                           !looks_icd(tok) && looks_icd(fix_tok(tok))
                         }, logical(1)))
                       }, logical(1))
                       cand_idx[fixable]
                     }
                   }
                 },
                 
                 "cat6_4" = {
                   # Likely ICD-9 usage: numeric-only tokens (3 digits with optional decimals) anywhere in the token list
                   if (is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     which(grepl("(^|;)\\d{3}(\\.?\\d{1,2})?(?=;|$)", icd_norm_all, perl = TRUE))
                   }
                 },
                 
                 "cat6_5" = {
                   if (is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     which(grepl("(^|;)(XXX|ZZZ|FAKE)(?=;|$)", icd_norm_all, perl = TRUE, ignore.case = TRUE))
                   }
                 },
                 
                 "cat6_6" = {
                   # Another ICD-9 heuristic (kept for backward compatibility with your check catalog)
                   if (is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     which(grepl("(^|;)\\d{3}\\.?\\d{1,2}(?=;|$)", icd_norm_all, perl = TRUE))
                   }
                 },
                 
                 "cat6_7" = {
                   # ICD length/shape out of range (token-wise)
                   if (is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     which(
                       grepl("(^|;)[^;]{1,2}(?=;|$)", icd_norm_all, perl = TRUE) |   # too short
                         grepl("(^|;)[^;]{7,}(?=;|$)", icd_norm_all, perl = TRUE)    # too long
                     )
                   }
                 },
                 
                 "cat6_8" = {
                   # OPS tokens must all match ^\d-\d{2,3}(\.[0-9A-Z]{1,4})?[LRB]?$  (token-wise)
                   if (is.null(ops_norm_all)) {
                     integer(0)
                   } else {
                     bad <- any_invalid_token(ops_norm_all, "[0-9]-[0-9]{2,3}(\\.[0-9A-Z]{1,4})?[LRB]?")
                     which(bad)
                   }
                 },
                 
                 "cat6_9" = {
                   # Foreign code system marker "Z9..." in ICD or OPS (token start)
                   has_i <- if (!is.null(icd_norm_all)) grepl("(^|;)Z9", icd_norm_all, perl = TRUE, ignore.case = TRUE) else rep(FALSE, n)
                   has_o <- if (!is.null(ops_norm_all)) grepl("(^|;)Z9", ops_norm_all, perl = TRUE, ignore.case = TRUE) else rep(FALSE, n)
                   which(has_i | has_o)
                 },
                 
                 "cat6_11" = {
                   if (is.null(icd_norm_all)) {
                     integer(0)
                   } else {
                     # Unspecific ICD usage:
                     # - R99
                     # - Z00 or Z00.*
                     # - any ICD token ending with .9 / .90 / .99
                     which(
                       grepl("(^|;)R99(?=;|$)", icd_norm_all, perl = TRUE) |
                         grepl("(^|;)Z00(\\.[0-9A-Z]{1,4})?(?=;|$)", icd_norm_all, perl = TRUE) |
                         grepl("\\.(9|90|99)(?=;|$)", icd_norm_all, perl = TRUE)
                     )
                   }
                 },
                 
                 
                 # Fallback: keep app stable
                 integer(0)
          )
          
        }, error = function(e) integer(0))
        
        if (length(flagged) > 0) add_issue(flagged, cid, cl, sev)
      }
      
      # -----------------------------
      # Custom checks (unchanged, but faster bind)
      # -----------------------------
      if (length(rv$custom_checks) > 0) {
        for (cc in rv$custom_checks) {
          tryCatch({
            flag_raw <- eval(rlang::parse_expr(cc$expression_raw), envir = df)
            # NA-safe: treat NA results as FALSE (not flagged)
            flag_raw[is.na(flag_raw)] <- FALSE
            flag <- which(as.logical(flag_raw))
            if (length(flag) > 0) {
              k <- k + 1L
              res_list[[k]] <- data.frame(
                row = flag,
                check_id = cc$check_id,
                issue = cc$description,
                severity = cc$severity,
                patient_id = if (!is.null(pid_col)) pid_col[flag] else rep(NA_character_, length(flag)),
                stringsAsFactors = FALSE
              )
            }
          }, error = function(e) NULL)
        }
      }
      
    }, t("loading"))
    
    # bind once
    if (length(res_list) > 0) {
      if (requireNamespace("data.table", quietly = TRUE)) {
        issues <- as.data.frame(data.table::rbindlist(res_list, use.names = TRUE, fill = TRUE))
      } else {
        issues <- do.call(rbind, res_list)
      }
    } else {
      issues <- data.frame(
        row = integer(), check_id = character(), issue = character(), severity = character(), patient_id = character(),
        stringsAsFactors = FALSE
      )
    }
    
    rv$issues <- if (nrow(issues) > 0) issues else NULL
    
    elapsed <- (proc.time() - t_start)[["elapsed"]]
    rv$check_time <- elapsed
    
    rv$perf_log <- rbind(
      rv$perf_log,
      data.frame(
        task = "Checks",
        source = paste0(length(sel), "+", length(rv$custom_checks), " checks"),
        rows = as.integer(n),
        duration_sec = round(elapsed, 3),
        timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        stringsAsFactors = FALSE
      )
    )
    
    rv$max_step <- 6
    session$sendCustomMessage("enable_pills", rv$max_step)
    
    safe_notify(paste("\u2705", if (!is.null(rv$issues)) nrow(rv$issues) else 0, "issue(s) |", round(elapsed, 2), "s"), "message")
  })
  
  
  # ── Results ─────────────────────────────────────────────────────────────────
  output$results_metrics <- renderUI({
    req(rv$mapped)
    iss <- rv$issues
    nr  <- nrow(rv$mapped)
    nc  <- tryCatch(length(get_selected_checks()) + length(rv$custom_checks), error = function(e) 0L)
    q   <- calc_quality_score(nr, iss)
    score <- q$score
    col   <- score_hex(score)
    
    div(class = "odqa-metrics",
        div(class = "odqa-metric m-checks",
            div(class = "metric-value", nc),
            div(class = "metric-label", t("s5_checks"))),
        div(class = "odqa-metric m-issues",
            div(class = "metric-value", q$issue_count),
            div(class = "metric-label", t("s5_issues"))),
        div(class = "odqa-metric m-affected",
            div(class = "metric-value", q$affected_rows),
            div(class = "metric-label", t("s5_affected"))),
        div(class = "odqa-metric m-score",
            div(class = "metric-value", style = paste0("color:", col, ";font-weight:900;"),
                paste0(score, "%")),
            div(class = "metric-label", t("s5_score_band_info")))
    )
  })
  
  output$results_score_info <- renderUI({
    div(class = "odqa-score-info", t("s5_score_info"))
  })
  
  output$results_interp <- renderUI({
    iss <- rv$issues
    if (is.null(iss) || nrow(iss) == 0)
      return(div(class = "odqa-interp level-ok",
                 div(class = "odqa-interp-icon", "\u2705"),
                 div(class = "odqa-interp-text", h4("Excellent"), p(t("interp_ok")))))
    
    sv <- table(iss$severity)
    has_cr <- ("Critical" %in% names(sv))
    has_hi <- ("High" %in% names(sv))
    has_md <- ("Medium" %in% names(sv))
    cards <- list()
    
    if (has_cr)
      cards <- c(cards, list(div(class = "odqa-interp level-cr",
                                 div(class = "odqa-interp-icon", "\U0001F6A8"),
                                 div(class = "odqa-interp-text", h4("Critical"), p(t("interp_cr"))))))
    if (has_hi)
      cards <- c(cards, list(div(class = "odqa-interp level-hi",
                                 div(class = "odqa-interp-icon", "\u26A0\uFE0F"),
                                 div(class = "odqa-interp-text", h4("High"), p(t("interp_hi"))))))
    if (has_md && !has_cr && !has_hi)
      cards <- c(cards, list(div(class = "odqa-interp level-md",
                                 div(class = "odqa-interp-icon", "\U0001F4CA"),
                                 div(class = "odqa-interp-text", h4("Moderate"), p(t("interp_md"))))))
    if (!has_cr && !has_hi && !has_md)
      cards <- c(cards, list(div(class = "odqa-interp level-lo",
                                 div(class = "odqa-interp-icon", "\u2139\uFE0F"),
                                 div(class = "odqa-interp-text", h4("Minor"), p(t("interp_lo"))))))
    
    tagList(cards)
  })
  
  # Charts (hardened with tryCatch)
  make_sev_plot <- function() {
    iss <- tryCatch(rv$issues, error = function(e) NULL)
    if (is.null(iss) || nrow(iss) == 0) return(NULL)
    sv <- as.data.frame(table(Severity = iss$severity), stringsAsFactors = FALSE)
    if (nrow(sv) == 0) return(NULL)
    cols <- c(Low = "#3B82F6", Medium = "#F59E0B", High = "#EF4444", Critical = "#BE123C")
    sv$Color <- cols[sv$Severity]
    sv$Color[is.na(sv$Color)] <- "#6B7280"
    par(mar = c(4, 8, 2, 2), family = "sans")
    bp <- barplot(sv$Freq, horiz = TRUE, col = sv$Color, border = NA, las = 1,
                  xlab = "Issues", names.arg = sv$Severity, cex.names = 0.9)
    text(sv$Freq, bp, labels = sv$Freq, pos = 4, cex = 0.9, font = 2)
  }
  
  make_cat_plot <- function() {
    iss <- tryCatch(rv$issues, error = function(e) NULL)
    if (is.null(iss) || nrow(iss) == 0) return(NULL)
    cdf <- rv$checks_df
    
    # ── Robust category derivation (works even if cdf lacks category) ──
    if ("category" %in% names(cdf)) {
      iss$category <- cdf$category[match(iss$check_id, cdf$check_id)]
    } else {
      # Fallback: derive from check_id prefix
      iss$category <- vapply(iss$check_id, function(id) {
        if (grepl("^cat1_", id)) "Completeness"
        else if (grepl("^cat2_", id)) "Age Plausibility"
        else if (grepl("^cat3_", id)) "Gender Plausibility"
        else if (grepl("^cat4_", id)) "Temporal Consistency"
        else if (grepl("^cat5_", id)) "Diagnosis-Procedure"
        else if (grepl("^cat6_", id)) "Code Integrity"
        else "Custom"
      }, character(1))
    }
    iss$category[is.na(iss$category) | !nzchar(iss$category)] <- "Custom"
    
    ct <- as.data.frame(table(Category = iss$category), stringsAsFactors = FALSE)
    if (nrow(ct) == 0) return(NULL)
    
    # Sort by frequency descending
    ct <- ct[order(-ct$Freq), , drop = FALSE]
    
    # Percentage calculation
    ct$Pct <- round(100 * ct$Freq / sum(ct$Freq), 1)
    ct$Label <- paste0(ct$Freq, " (", ct$Pct, "%)")
    
    cols <- c(Completeness = "#0866FF", `Age Plausibility` = "#7C3AED",
              `Gender Plausibility` = "#EC4899", `Temporal Consistency` = "#F59E0B",
              `Diagnosis-Procedure` = "#10B981", `Code Integrity` = "#EF4444",
              Custom = "#6366F1")
    ct$Color <- cols[ct$Category]
    ct$Color[is.na(ct$Color)] <- "#6366F1"
    
    oldpar <- par(no.readonly = TRUE)
    on.exit(par(oldpar), add = TRUE)
    par(mar = c(4, 13, 3, 5), family = "sans")
    
    bp <- barplot(ct$Freq, horiz = TRUE, col = ct$Color, border = NA, las = 1,
                  xlab = "Issues", names.arg = ct$Category, cex.names = 0.85,
                  main = "Issue Distribution by Category")
    
    # Labels with count + percentage inside or beside bars
    x_max <- max(ct$Freq, na.rm = TRUE)
    for (i in seq_len(nrow(ct))) {
      x_pos <- ct$Freq[i]
      lbl <- ct$Label[i]
      # Place label outside bar if bar is too narrow for text
      if (x_pos < x_max * 0.25) {
        text(x_pos, bp[i], labels = lbl, pos = 4, cex = 0.85, font = 2,
             col = "#1C1E21")
      } else {
        text(x_pos * 0.5, bp[i], labels = lbl, cex = 0.85, font = 2,
             col = "white")
      }
    }
  }
  
  output$plot_severity <- renderPlot({ tryCatch(make_sev_plot(), error = function(e) NULL) }, bg = "transparent")
  output$plot_category <- renderPlot({ tryCatch(make_cat_plot(), error = function(e) NULL) }, bg = "transparent")
  
  output$dt_issues <- renderDT({
    iss <- rv$issues
    if (is.null(iss) || nrow(iss) == 0) {
      return(datatable(
        data.frame(Status = "No issues detected", stringsAsFactors = FALSE),
        options = list(dom = "t"), rownames = FALSE))
    }
    datatable(
      iss,
      options = list(
        pageLength = 20,
        scrollX = TRUE,
        deferRender = TRUE,
        processing = TRUE,
        language = list(search = switch(L(), de = "Suche:", fr = "Recherche:", "Search:"))
      ),
      rownames = FALSE,
      class = "compact stripe",
      filter = "top"
    )
  })
  
  check_summary <- reactive({
    req(rv$mapped)
    tryCatch(
      issues_by_check(rv$issues, rv$checks_df, nrow(rv$mapped)),
      error = function(e) NULL
    )
  })
  
  output$s5_check_pick_ui <- renderUI({
    df <- check_summary()
    if (is.null(df) || nrow(df) == 0) {
      return(div(class = "odqa-hint success",
                 span(class = "odqa-hint-icon", "\u2705"),
                 span(switch(L(),
                             de = "Keine Pr\u00fcfungen mit Problemen.",
                             fr = "Aucune v\u00e9rification avec des probl\u00e8mes.",
                             "No checks with issues to display."))))
    }
    choices <- setNames(df$check_id, paste0("[", df$check_id, "] ", df$check_name))
    selectInput("s5_check_pick",
                switch(L(), de = "Pr\u00fcfung ausw\u00e4hlen", fr = "Choisir une v\u00e9rification", "Select check"),
                choices = choices, selected = df$check_id[1], width = "100%")
  })
  
  output$plot_check_impact <- renderPlot({
    req(rv$mapped)
    df <- check_summary()
    if (is.null(df) || nrow(df) == 0) return(NULL)
    pick <- input$s5_check_pick %||% df$check_id[1]
    row <- df[df$check_id == pick, , drop = FALSE]
    if (nrow(row) == 0) return(NULL)
    
    tryCatch(
      plot_check_impact(row$affected_n[1], nrow(rv$mapped),
                        paste0("[", row$check_id[1], "] ", row$check_name[1]),
                        paste0("Affected: ", row$affected_n[1], " (", row$affected_pct[1],
                               "%) | Severity: ", row$severity[1])),
      error = function(e) NULL
    )
  }, bg = "transparent")
  
  output$dt_check_summary <- renderDT({
    df <- check_summary()
    if (is.null(df) || nrow(df) == 0) {
      return(datatable(data.frame(Status = "No issues", stringsAsFactors = FALSE),
                       options = list(dom = "t"), rownames = FALSE))
    }
    out <- df[, intersect(c("check_id","check_name","severity","affected_n","affected_pct","required"), names(df)), drop = FALSE]
    col_names <- c(check_id = "Check ID", check_name = "Medical Name", severity = "Severity",
                   affected_n = "Affected rows", affected_pct = "Affected %", required = "Required columns")
    names(out) <- col_names[names(out)]
    datatable(out, options = list(pageLength = 10, scrollX = TRUE,
                                  language = list(search = switch(L(), de = "Suche:", fr = "Recherche:", "Search:"))),
              rownames = FALSE, class = "compact stripe")
  })  
  
  save_chart_png <- function(plot_fn, filename) {
    f <- file.path(tempdir(), filename)
    png(f, width = 1200, height = 600, res = 150)
    tryCatch(plot_fn(), error = function(e) NULL); dev.off()
    if (file.exists(f)) f else NULL
  }
  output$dl_word <- downloadHandler(
    filename = function() paste0("odqa_dqa_proof_", format(Sys.time(), "%Y%m%d_%H%M"), ".docx"),
    content = function(file) {
      tryCatch({
        nc <- length(get_selected_checks()) + length(rv$custom_checks)
        sev_f <- save_chart_png(make_sev_plot, "sev_plot.png")
        cat_f <- save_chart_png(make_cat_plot, "cat_plot.png")
        doc <- gen_word(
          issues          = rv$issues,
          n_checks        = nc,
          mapped_df       = rv$mapped,
          lang            = L(),
          sev_plot        = sev_f,
          cat_plot        = cat_f,
          user_info       = rv$user_info,
          perf_data       = rv$perf_log,
          checks_df       = rv$checks_df,
          selected_checks = get_selected_checks(),
          custom_checks   = rv$custom_checks
        )
        print(doc, target = file)
      }, error = function(e) {
        # Fallback: write minimal error report
        doc <- officer::read_docx()
        doc <- officer::body_add_par(doc, "Open DQA Report Generation Error", style = "heading 1")
        doc <- officer::body_add_par(doc, paste("Error:", e$message), style = "Normal")
        doc <- officer::body_add_par(doc, paste("Timestamp:", Sys.time()), style = "Normal")
        print(doc, target = file)
      })
    })
  output$dl_csv <- downloadHandler(
    filename = function() paste0("odqa_issues_", format(Sys.time(), "%Y%m%d_%H%M"), ".csv"),
    content = function(file) {
      tryCatch({
        if (!is.null(rv$issues) && nrow(rv$issues) > 0) {
          write.csv(rv$issues, file, row.names = FALSE, fileEncoding = "UTF-8")
        } else {
          write.csv(data.frame(Status = "No issues detected", Timestamp = as.character(Sys.time())),
                    file, row.names = FALSE)
        }
      }, error = function(e) {
        write.csv(data.frame(Error = e$message), file, row.names = FALSE)
      })
    })
  
  
  # ── Cleansing ───────────────────────────────────────────────────────────────
  # ── Issue-guided cleansing ──────────────────────────────────────────────────
  output$cl_issue_select <- renderUI({
    iss <- rv$issues
    if (is.null(iss) || nrow(iss) == 0)
      return(div(class = "odqa-hint success",
                 span(class = "odqa-hint-icon", "\u2705"), span(t("no_issues"))))
    
    # Build grouped, informative choices
    issue_labels <- paste0("[", iss$check_id, "] ", iss$issue)
    choices <- unique(issue_labels)
    
    # Add counts to choices
    counts <- table(issue_labels)
    display_choices <- setNames(
      names(counts),
      paste0(names(counts), " (", as.integer(counts), " rows)")
    )
    
    selectInput("cl_issue",
                switch(L(), de = "Problem ausw\u00e4hlen", fr = "S\u00e9lectionner le probl\u00e8me", "Select Issue"),
                choices = display_choices, width = "100%")
  })
  
  # Helper: get affected rows for the selected issue
  cl_get_affected_rows <- reactive({
    req(rv$issues, input$cl_issue, rv$cl_data)
    pat <- sub("^\\[([^]]+)\\].*", "\\1", input$cl_issue)
    rows <- rv$issues$row[rv$issues$check_id == pat]
    rows <- rows[!is.na(rows) & rows >= 1 & rows <= nrow(rv$cl_data)]
    unique(rows)
  })
  
  cl_affected <- reactive({
    rows <- cl_get_affected_rows()
    if (length(rows) == 0) return(data.frame())
    rv$cl_data[rows, , drop = FALSE]
  })
  
  # Show Affected Rows
  observeEvent(input$cl_show, {
    aff <- cl_affected()
    output$dt_cl_affected <- renderDT({
      if (is.null(aff) || nrow(aff) == 0) {
        return(datatable(data.frame(Info = "No affected rows found"),
                         options = list(dom = "t"), rownames = FALSE))
      }
      datatable(aff,
                options = list(pageLength = 10, scrollX = TRUE, dom = "ltip",
                               language = list(search = switch(L(), de = "Suche:", fr = "Recherche:", "Search:"))),
                rownames = TRUE, class = "compact stripe")
    })
  })
  
  # Delete Affected Rows
  observeEvent(input$cl_del_rows, {
    rows <- cl_get_affected_rows()
    if (length(rows) == 0) { safe_notify("No rows to delete.", "warning"); return() }
    
    cl_undo_push(rv, rv$cl_data)
    pat <- sub("^\\[([^]]+)\\].*", "\\1", input$cl_issue)
    
    # data.table: negative indexing is efficient, no copy
    if (data.table::is.data.table(rv$cl_data)) {
      keep <- setdiff(seq_len(nrow(rv$cl_data)), rows)
      rv$cl_data <- rv$cl_data[keep]
    } else {
      rv$cl_data <- rv$cl_data[-rows, , drop = FALSE]
    }
    
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      Timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      Action = paste0("Delete rows [", pat, "]"),
      Column = "--",
      Rows = paste0(length(rows), " rows (indices: ",
                    paste(head(rows, 5), collapse = ","),
                    if (length(rows) > 5) "..." else "", ")"),
      Old = "removed",
      New = "--",
      stringsAsFactors = FALSE
    ))
    safe_notify(paste("\u2705 Deleted", length(rows), "rows"), "message")
  })
  
  # Keep As Is (logs the decision)
  observeEvent(input$cl_keep_as_is, {
    rows <- cl_get_affected_rows()
    if (length(rows) == 0) { safe_notify("No rows to review.", "warning"); return() }
    
    pat <- sub("^\\[([^]]+)\\].*", "\\1", input$cl_issue)
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      Timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      Action = paste0("Keep as is [", pat, "]"),
      Column = "--",
      Rows = paste0(length(rows), " rows"),
      Old = "reviewed",
      New = "kept unchanged (justified)",
      stringsAsFactors = FALSE
    ))
    safe_notify(paste("\u2705 Kept", length(rows), "rows as is (decision logged)"), "message")
  })
  
  # ── Edit Value panel ────────────────────────────────────────────────────────
  rv_edit <- reactiveValues(active = FALSE)
  
  output$cl_edit_panel <- renderUI({
    if (!isTRUE(rv_edit$active)) return(NULL)
    req(rv$cl_data)
    cn <- names(rv$cl_data)
    # Remove internal columns from selection
    cn <- cn[!cn %in% c(".row_id")]
    
    rows <- cl_get_affected_rows()
    n_rows <- length(rows)
    
    div(class = "odqa-hint warning", style = "flex-direction:column;align-items:stretch;",
        span(style = "font-weight:700;margin-bottom:8px;",
             paste0(switch(L(),
                           de = paste0(n_rows, " betroffene Zeilen \u2013 Spalte und neuen Wert w\u00e4hlen:"),
                           fr = paste0(n_rows, " lignes affect\u00e9es \u2013 choisir colonne et nouvelle valeur:"),
                           paste0(n_rows, " affected rows \u2013 select column and enter replacement value:")))),
        fluidRow(
          column(3, selectInput("cl_edit_col",
                                switch(L(), de = "Spalte", fr = "Colonne", "Column"), cn, width = "100%")),
          column(4, textInput("cl_edit_new_val",
                              switch(L(), de = "Neuer Wert", fr = "Nouvelle valeur", "New Value"),
                              "", width = "100%")),
          column(2, actionButton("cl_save_edit",
                                 switch(L(), de = "Speichern", fr = "Enregistrer", "Save"),
                                 class = "btn-odqa btn-odqa-success", icon = icon("floppy-disk"),
                                 style = "margin-top:25px")),
          column(2, actionButton("cl_cancel_edit",
                                 switch(L(), de = "Abbrechen", fr = "Annuler", "Cancel"),
                                 class = "btn-odqa btn-odqa-ghost", style = "margin-top:25px"))))
  })
  
  observeEvent(input$cl_edit_val, { rv_edit$active <- TRUE })
  observeEvent(input$cl_cancel_edit, { rv_edit$active <- FALSE })
  
  observeEvent(input$cl_save_edit, {
    req(rv$cl_data, input$cl_edit_col)
    new_val <- input$cl_edit_new_val
    
    rows <- cl_get_affected_rows()
    if (length(rows) == 0) { safe_notify("No rows to edit.", "warning"); return() }
    
    col <- input$cl_edit_col
    if (!col %in% names(rv$cl_data)) { safe_notify("Column not found.", "error"); return() }
    
    cl_undo_push(rv, rv$cl_data)
    
    old_vals <- unique(as.character(rv$cl_data[[col]][rows]))
    old_summary <- paste(head(old_vals, 3), collapse = ", ")
    if (length(old_vals) > 3) old_summary <- paste0(old_summary, "...")
    
    # ── data.table in-place mutation via set() — zero copy ──
    if (data.table::is.data.table(rv$cl_data)) {
      target_col <- rv$cl_data[[col]]
      if (is.numeric(target_col)) {
        num_val <- suppressWarnings(as.numeric(new_val))
        if (!is.na(num_val)) {
          data.table::set(rv$cl_data, i = as.integer(rows), j = col, value = num_val)
        } else {
          # Convert column to character if needed
          data.table::set(rv$cl_data, i = as.integer(rows), j = col, value = new_val)
        }
      } else if (is.integer(target_col)) {
        int_val <- suppressWarnings(as.integer(new_val))
        if (!is.na(int_val)) {
          data.table::set(rv$cl_data, i = as.integer(rows), j = col, value = int_val)
        } else {
          data.table::set(rv$cl_data, i = as.integer(rows), j = col, value = new_val)
        }
      } else {
        data.table::set(rv$cl_data, i = as.integer(rows), j = col, value = new_val)
      }
    } else {
      # Fallback for plain data.frame
      target_col <- rv$cl_data[[col]]
      if (is.numeric(target_col)) {
        num_val <- suppressWarnings(as.numeric(new_val))
        if (!is.na(num_val)) rv$cl_data[[col]][rows] <- num_val
        else rv$cl_data[[col]][rows] <- new_val
      } else if (is.integer(target_col)) {
        int_val <- suppressWarnings(as.integer(new_val))
        if (!is.na(int_val)) rv$cl_data[[col]][rows] <- int_val
        else rv$cl_data[[col]][rows] <- new_val
      } else {
        rv$cl_data[[col]][rows] <- new_val
      }
    }
    
    pat <- sub("^\\[([^]]+)\\].*", "\\1", input$cl_issue %||% "manual")
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      Timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      Action = paste0("Edit values [", pat, "]"),
      Column = col,
      Rows = paste0(length(rows), " rows"),
      Old = old_summary,
      New = new_val,
      stringsAsFactors = FALSE
    ))
    rv_edit$active <- FALSE
    safe_notify(paste("\u2705 Updated", length(rows), "values in", col), "message")
  })
  
  # ── Find & Replace (enhanced) ──────────────────────────────────────────────
  output$cl_fr_col_ui <- renderUI({
    req(rv$cl_data)
    cn <- names(rv$cl_data)
    cn <- cn[!cn %in% c(".row_id")]
    selectInput("cl_fr_col",
                switch(L(), de = "Spalte", fr = "Colonne", "Column"),
                cn, width = "100%")
  })
  
  fr_match_idx <- reactive({
    req(rv$cl_data, input$cl_fr_col, nzchar(input$cl_find))
    col_name <- input$cl_fr_col
    if (!col_name %in% names(rv$cl_data)) return(integer(0))
    
    vals <- as.character(rv$cl_data[[col_name]])
    pattern <- input$cl_find
    use_regex <- isTRUE(input$cl_fr_regex)
    case_sens <- isTRUE(input$cl_fr_case)
    
    idx <- tryCatch({
      if (use_regex) {
        grep(pattern, vals, ignore.case = !case_sens)
      } else {
        if (case_sens) which(vals == pattern)
        else which(tolower(vals) == tolower(pattern))
      }
    }, error = function(e) {
      safe_notify(paste("Pattern error:", e$message), "warning")
      integer(0)
    })
    idx
  })
  
  observeEvent(input$cl_fr_preview, {
    idx <- fr_match_idx()
    output$cl_fr_preview_ui <- renderUI({
      n <- length(idx)
      if (n == 0) return(div(class = "odqa-hint warning",
                             span(class = "odqa-hint-icon", "\u26A0\uFE0F"),
                             span(switch(L(), de = "Keine Treffer.", fr = "Aucune correspondance.", "No matches found."))))
      sample_vals <- unique(as.character(rv$cl_data[[input$cl_fr_col]][idx]))[seq_len(min(5, n))]
      div(class = "odqa-hint info",
          span(class = "odqa-hint-icon", "\U0001F50D"),
          span(paste0(n, " ", t("s6_fr_count"), ". ",
                      switch(L(), de = "Beispiele: ", fr = "Exemples: ", "Sample: "),
                      paste(sample_vals, collapse = " | "))))
    })
  })
  
  observeEvent(input$cl_fr_go, {
    req(rv$cl_data, input$cl_fr_col, nzchar(input$cl_find))
    idx <- fr_match_idx()
    if (length(idx) == 0) {
      safe_notify(switch(L(), de = "Keine Treffer.", fr = "Aucune correspondance.",
                         "No matches."), "warning")
      return()
    }
    
    cl_undo_push(rv, rv$cl_data)
    col <- input$cl_fr_col
    
    # ── data.table chunked processing for 10M+ rows ──
    if (data.table::is.data.table(rv$cl_data)) {
      if (isTRUE(input$cl_fr_regex)) {
        # Regex: process in chunks of 2M rows to limit memory spikes
        chunk_size <- 2000000L
        all_rows <- seq_len(nrow(rv$cl_data))
        n_chunks <- ceiling(length(all_rows) / chunk_size)
        for (ch in seq_len(n_chunks)) {
          start_i <- (ch - 1L) * chunk_size + 1L
          end_i <- min(ch * chunk_size, length(all_rows))
          chunk_rows <- all_rows[start_i:end_i]
          old_chunk <- as.character(rv$cl_data[[col]][chunk_rows])
          new_chunk <- sub(input$cl_find, input$cl_repl, old_chunk,
                           ignore.case = !isTRUE(input$cl_fr_case))
          changed <- which(old_chunk != new_chunk)
          if (length(changed) > 0) {
            data.table::set(rv$cl_data, i = chunk_rows[changed], j = col,
                            value = new_chunk[changed])
          }
        }
      } else {
        # Exact match: direct set on matched indices
        data.table::set(rv$cl_data, i = as.integer(idx), j = col,
                        value = input$cl_repl)
      }
    } else {
      # Fallback for plain data.frame
      if (isTRUE(input$cl_fr_regex)) {
        old_vals <- as.character(rv$cl_data[[col]])
        rv$cl_data[[col]] <- sub(input$cl_find, input$cl_repl,
                                 old_vals, ignore.case = !isTRUE(input$cl_fr_case))
      } else {
        rv$cl_data[[col]][idx] <- input$cl_repl
      }
    }
    
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      Timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      Action = paste0("Find & Replace", if (isTRUE(input$cl_fr_regex)) " (regex)" else ""),
      Column = col,
      Rows = paste0(length(idx), " cells"),
      Old = input$cl_find,
      New = input$cl_repl,
      stringsAsFactors = FALSE
    ))
    output$cl_fr_preview_ui <- renderUI(NULL)
    safe_notify(paste("\u2705 Replaced", length(idx), "values"), "message")
  })
  
  # ── Rename Column ──────────────────────────────────────────────────────────
  output$cl_rename_col_ui <- renderUI({
    req(rv$cl_data)
    cn <- names(rv$cl_data)
    cn <- cn[!cn %in% c(".row_id")]
    selectInput("cl_rename_col",
                switch(L(), de = "Spalte", fr = "Colonne", "Column"),
                cn, width = "100%")
  })
  
  observeEvent(input$cl_rename_go, {
    req(rv$cl_data, input$cl_rename_col, nzchar(input$cl_new_name))
    old_name <- input$cl_rename_col
    new_name <- trimws(input$cl_new_name)
    
    if (new_name %in% names(rv$cl_data)) {
      safe_notify(switch(L(), de = "Name existiert bereits!", fr = "Nom existant!", "Name already exists!"), "error")
      return()
    }
    if (!nzchar(new_name) || grepl("[^a-zA-Z0-9_.]", new_name)) {
      safe_notify(switch(L(), de = "Ung\u00fcltiger Name.", fr = "Nom invalide.", "Invalid column name. Use alphanumeric characters, dots, and underscores."), "error")
      return()
    }
    
    cl_undo_push(rv, rv$cl_data)
    if (data.table::is.data.table(rv$cl_data)) {
      data.table::setnames(rv$cl_data, old_name, new_name)
    } else {
      idx <- which(names(rv$cl_data) == old_name)
      if (length(idx) == 0) { safe_notify("Column not found.", "error"); return() }
      names(rv$cl_data)[idx] <- new_name
    }
    
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      Timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      Action = "Rename column", Column = old_name,
      Rows = "all", Old = old_name, New = new_name,
      stringsAsFactors = FALSE
    ))
    safe_notify(paste("\u2705", old_name, "\u2192", new_name), "message")
  })
  
  # ── Fix Date Format ────────────────────────────────────────────────────────
  output$cl_datefix_col_ui <- renderUI({
    req(rv$cl_data)
    cn <- names(rv$cl_data)
    cn <- cn[!cn %in% c(".row_id")]
    selectInput("cl_datefix_col",
                switch(L(), de = "Datumsspalte", fr = "Colonne date", "Date column"),
                cn, width = "100%")
  })
  
  observeEvent(input$cl_datefix_go, {
    req(rv$cl_data, input$cl_datefix_col)
    col <- input$cl_datefix_col
    if (!col %in% names(rv$cl_data)) { safe_notify("Column not found.", "error"); return() }
    
    cl_undo_push(rv, rv$cl_data)
    old_vals <- as.character(rv$cl_data[[col]])
    
    # Multi-format date parsing
    parsed <- suppressWarnings(as.Date(old_vals))
    best_count <- sum(!is.na(parsed))
    best_parsed <- parsed
    
    for (fmt in c("%d.%m.%Y", "%d/%m/%Y", "%m/%d/%Y", "%d-%m-%Y", "%Y%m%d", "%d.%m.%y", "%m-%d-%Y")) {
      attempt <- suppressWarnings(as.Date(old_vals, format = fmt))
      n_ok <- sum(!is.na(attempt))
      if (n_ok > best_count) {
        best_count <- n_ok
        best_parsed <- attempt
      }
    }
    
    if (data.table::is.data.table(rv$cl_data)) {
      data.table::set(rv$cl_data, j = col, value = as.character(best_parsed))
    } else {
      rv$cl_data[[col]] <- as.character(best_parsed)
    }
    
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      Timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      Action = "Fix date format", Column = col,
      Rows = paste0(best_count, " dates converted"),
      Old = "mixed formats",
      New = "YYYY-MM-DD (ISO 8601)",
      stringsAsFactors = FALSE
    ))
    safe_notify(paste("\u2705 Converted", best_count, "dates to ISO 8601"), "message")
  })
  
  # ── Delete Column ──────────────────────────────────────────────────────────
  output$cl_delcol_ui <- renderUI({
    req(rv$cl_data)
    cn <- names(rv$cl_data)
    cn <- cn[!cn %in% c(".row_id")]
    selectInput("cl_delcol_sel",
                switch(L(), de = "Spalte l\u00f6schen", fr = "Supprimer colonne", "Delete Column"),
                cn, width = "100%")
  })
  
  observeEvent(input$cl_delcol, {
    req(rv$cl_data, input$cl_delcol_sel)
    col <- input$cl_delcol_sel
    if (col == ".row_id") { safe_notify("Cannot delete internal column.", "error"); return() }
    if (!col %in% names(rv$cl_data)) { safe_notify("Column not found.", "error"); return() }
    
    cl_undo_push(rv, rv$cl_data)
    
    if (data.table::is.data.table(rv$cl_data)) {
      data.table::set(rv$cl_data, j = col, value = NULL)
    } else {
      rv$cl_data[[col]] <- NULL
    }
    
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      Timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      Action = "Delete column", Column = col,
      Rows = "all", Old = "removed", New = "--",
      stringsAsFactors = FALSE
    ))
    safe_notify(paste("\u2705 Column '", col, "' deleted"), "message")
  })
  
  # ── Undo (all variants, unified) ──────────────────────────────────────────
  do_undo <- function() {
    prev <- cl_undo_pop(rv)
    if (is.null(prev)) {
      safe_notify(switch(L(), de = "Nichts zum R\u00fcckg\u00e4ngig machen.", fr = "Rien \u00e0 annuler.", "Nothing to undo."), "warning")
      return()
    }
    rv$cl_data <- prev
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      Timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      Action = "UNDO", Column = "--", Rows = "--",
      Old = "--", New = "reverted to previous state",
      stringsAsFactors = FALSE
    ))
    rv$compare_ready <- FALSE
    safe_notify("\u21A9\uFE0F Undone!", "message")
  }
  
  observeEvent(input$cl_undo, do_undo())
  observeEvent(input$cl_undo_del, do_undo())
  observeEvent(input$cl_undo_fr, do_undo())
  observeEvent(input$cl_undo_rename, do_undo())
  observeEvent(input$cl_undo_datefix, do_undo())
  
  # ══════════════════════════════════════════════════════════════════════════
  # MANUAL CELL EDITING (V0.1: FIXED back-end write-through)
  # ══════════════════════════════════════════════════════════════════════════
  
  output$s6_manual_hint <- renderUI({
    span(switch(L(),
                de = "Doppelklicken Sie auf eine Zelle \u2192 Neuen Wert eingeben \u2192 Tab oder Enter. Jede \u00c4nderung wird automatisch im Audit-Trail protokolliert. Die Spalte '.row_id' ist schreibgesch\u00fctzt.",
                fr = "Double-cliquez sur une cellule \u2192 Tapez la nouvelle valeur \u2192 Tab ou Entr\u00e9e. Chaque modification est enregistr\u00e9e automatiquement.",
                "Double-click any cell \u2192 Type new value \u2192 Press Tab or Enter. Every change is logged in the audit trail. The '.row_id' column is read-only."))
  })
  
  output$dt_cl_edit <- renderDT({
    req(rv$cl_data)
    
    dt <- rv$cl_data
    
    # Ensure .row_id column for stable indexing
    if (!".row_id" %in% names(dt)) {
      dt <- data.table::as.data.table(dt)
      dt[, .row_id := .I]
      data.table::setcolorder(dt, c(".row_id", setdiff(names(dt), ".row_id")))
      rv$cl_data <- dt
    }
    
    n_cols <- ncol(dt)
    
    datatable(
      dt,
      editable = list(target = "cell", disable = list(columns = c(0))),
      extensions = c("KeyTable"),
      options = list(
        keys = TRUE,
        pageLength = 15,
        scrollX = TRUE,
        autoWidth = FALSE,
        columnDefs = list(
          list(targets = 0, visible = FALSE, searchable = FALSE)
        ),
        processing = TRUE,
        language = list(search = switch(L(), de = "Suche:", fr = "Recherche:", "Search:"))
      ),
      rownames = FALSE,
      class = "compact stripe hover cell-border",
      filter = "top"
    )
  })
  
  # ── Cell edit handler (CRITICAL FIX: correct column index mapping) ────────
  observeEvent(input$dt_cl_edit_cell_edit, {
    info <- input$dt_cl_edit_cell_edit
    req(rv$cl_data, info)
    
    # DT returns 0-based row and column indices when rownames = FALSE
    r <- as.integer(info$row)
    c0 <- as.integer(info$col)
    newv <- info$value
    
    if (is.na(r) || is.na(c0) || r < 1) return()
    
    # Column index: DT with rownames=FALSE sends 0-based column index
    # Column 0 = .row_id (hidden, disabled), column 1 = first visible column
    # We need 1-based R index: j = c0 + 1 (since c0 is 0-based)
    j <- c0 + 1L
    
    dt <- data.table::as.data.table(rv$cl_data)
    if (j < 1 || j > ncol(dt)) return()
    
    col_name <- names(dt)[j]
    
    # Refuse editing .row_id
    if (identical(col_name, ".row_id")) return()
    
    # Ensure row is in range
    if (r > nrow(dt)) return()
    
    # Get old value for logging
    old_val <- tryCatch(as.character(dt[[col_name]][r]), error = function(e) "?")
    
    # Type-aware value coercion
    target_col <- dt[[col_name]]
    coerced <- tryCatch({
      if (is.numeric(target_col) && !is.integer(target_col)) {
        as.numeric(newv)
      } else if (is.integer(target_col)) {
        as.integer(newv)
      } else if (is.logical(target_col)) {
        as.logical(newv)
      } else if (inherits(target_col, "Date")) {
        as.Date(as.character(newv))
      } else {
        as.character(newv)
      }
    }, error = function(e) as.character(newv),
    warning = function(w) as.character(newv))
    
    # Apply the edit
    data.table::set(dt, i = as.integer(r), j = col_name, value = coerced)
    rv$cl_data <- dt
    
    # Log the change
    row_id_val <- tryCatch(dt$.row_id[r], error = function(e) r)
    rv$cl_log <- rbind(rv$cl_log, data.frame(
      Timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      Action = "manual_cell_edit",
      Column = col_name,
      Rows = as.character(row_id_val),
      Old = old_val,
      New = as.character(newv),
      stringsAsFactors = FALSE
    ))
  })
  
  # ── Audit Trail ────────────────────────────────────────────────────────────
  output$dt_cl_log <- renderDT({
    cl <- rv$cl_log
    if (is.null(cl) || nrow(cl) == 0) {
      return(datatable(
        data.frame(Info = switch(L(),
                                 de = "Noch keine \u00c4nderungen.",
                                 fr = "Aucune modification.",
                                 "No changes yet."), stringsAsFactors = FALSE),
        options = list(dom = "t"), rownames = FALSE))
    }
    datatable(
      cl[order(cl$Timestamp, decreasing = TRUE), ],
      options = list(pageLength = 10, dom = "ltip", scrollX = TRUE,
                     language = list(search = switch(L(), de = "Suche:", fr = "Recherche:", "Search:"))),
      rownames = FALSE, class = "compact stripe"
    )
  })
  
  # ── Compare (Original vs. Cleaned) ────────────────────────────────────────
  observeEvent(input$cl_gen_compare, {
    rv$compare_ready <- TRUE
    safe_notify("\u2705 Comparison generated!", "message")
  })
  
  output$dt_cl_orig_diff <- renderUI({
    if (!isTRUE(rv$compare_ready)) {
      return(div(style = "text-align:center;padding:30px;color:var(--text-tertiary);",
                 p(switch(L(),
                          de = "Klicken Sie 'Vergleich generieren'.",
                          fr = "Cliquez 'G\u00e9n\u00e9rer la comparaison'.",
                          "Click 'Generate Comparison' to compare."))))
    }
    req(rv$mapped)
    orig <- head(rv$mapped, 200)
    tagList(
      h4("Original", style = "font-size:13px;font-weight:700;color:var(--text-secondary);"),
      renderDT(datatable(orig,
                         options = list(pageLength = 8, scrollX = TRUE, dom = "tip"),
                         rownames = FALSE, class = "compact"))
    )
  })
  
  output$dt_cl_clean_diff <- renderUI({
    if (!isTRUE(rv$compare_ready)) return(NULL)
    req(rv$cl_data)
    clean <- head(rv$cl_data, 200)
    # Remove internal .row_id for display
    clean$.row_id <- NULL
    tagList(
      h4(switch(L(), de = "Bereinigt", fr = "Nettoy\u00e9", "Cleaned"),
         style = "font-size:13px;font-weight:700;color:var(--success);"),
      renderDT(datatable(clean,
                         options = list(pageLength = 8, scrollX = TRUE, dom = "tip"),
                         rownames = FALSE, class = "compact"))
    )
  })
  
  # ── Downloads ──────────────────────────────────────────────────────────────
  output$dl_cl_data <- downloadHandler(
    filename = function() paste0("odqa_cleaned_", format(Sys.time(), "%Y%m%d_%H%M"), ".csv"),
    content = function(file) {
      tryCatch({
        export_df <- rv$cl_data
        # Remove internal columns
        export_df$.row_id <- NULL
        write.csv(export_df, file, row.names = FALSE, fileEncoding = "UTF-8")
      }, error = function(e) {
        write.csv(data.frame(Error = e$message), file, row.names = FALSE)
        safe_notify(paste("Export error:", e$message), "error")
      })
    })
  
  output$dl_cl_log_word <- downloadHandler(
    filename = function() paste0("odqa_changelog_", format(Sys.time(), "%Y%m%d_%H%M"), ".docx"),
    content = function(file) {
      tryCatch({
        doc <- gen_cl_word(rv$cl_log, L(), user_info = rv$user_info)
        print(doc, target = file)
      }, error = function(e) {
        doc <- officer::read_docx()
        doc <- officer::body_add_par(doc, "Changelog Export Error", style = "heading 1")
        doc <- officer::body_add_par(doc, paste("Error:", e$message), style = "Normal")
        print(doc, target = file)
      })
    })
  
  output$dl_cl_log_csv <- downloadHandler(
    filename = function() paste0("odqa_changelog_", format(Sys.time(), "%Y%m%d_%H%M"), ".csv"),
    content = function(file) {
      tryCatch({
        write.csv(rv$cl_log, file, row.names = FALSE, fileEncoding = "UTF-8")
      }, error = function(e) {
        write.csv(data.frame(Error = e$message), file, row.names = FALSE)
      })
    })
  
  # ── Finish Page Download Handlers (mirrors Step 5/6 downloads) ──────────────
  output$dl_final_word <- downloadHandler(
    filename = function() paste0("odqa_dq_report_", format(Sys.time(), "%Y%m%d_%H%M"), ".docx"),
    content = function(file) {
      tryCatch({
        nc <- length(get_selected_checks()) + length(rv$custom_checks)
        sev_f <- save_chart_png(make_sev_plot, "sev_plot.png")
        cat_f <- save_chart_png(make_cat_plot, "cat_plot.png")
        doc <- gen_word(
          issues          = rv$issues,
          n_checks        = nc,
          mapped_df       = rv$mapped,
          lang            = L(),
          sev_plot        = sev_f,
          cat_plot        = cat_f,
          user_info       = rv$user_info,
          perf_data       = rv$perf_log,
          checks_df       = rv$checks_df,
          selected_checks = get_selected_checks(),
          custom_checks   = rv$custom_checks,
          cat_plot_file   = cat_f
        )
        print(doc, target = file)
      }, error = function(e) {
        doc <- officer::read_docx()
        doc <- officer::body_add_par(doc, "DQ Report Export Error", style = "heading 1")
        doc <- officer::body_add_par(doc, paste("Error:", e$message), style = "Normal")
        print(doc, target = file)
      })
    })
  
  output$dl_final_csv <- downloadHandler(
    filename = function() paste0("odqa_issues_", format(Sys.time(), "%Y%m%d_%H%M"), ".csv"),
    content = function(file) {
      tryCatch({
        write.csv(rv$issues %||% data.frame(), file, row.names = FALSE, fileEncoding = "UTF-8")
      }, error = function(e) {
        write.csv(data.frame(Error = e$message), file, row.names = FALSE)
      })
    })
  
  output$dl_final_cl_word <- downloadHandler(
    filename = function() paste0("odqa_changelog_", format(Sys.time(), "%Y%m%d_%H%M"), ".docx"),
    content = function(file) {
      tryCatch({
        doc <- gen_cl_word(rv$cl_log, L(), user_info = rv$user_info)
        print(doc, target = file)
      }, error = function(e) {
        doc <- officer::read_docx()
        doc <- officer::body_add_par(doc, "Changelog Export Error", style = "heading 1")
        doc <- officer::body_add_par(doc, paste("Error:", e$message), style = "Normal")
        print(doc, target = file)
      })
    })
  
  output$dl_final_cl_csv <- downloadHandler(
    filename = function() paste0("odqa_changelog_", format(Sys.time(), "%Y%m%d_%H%M"), ".csv"),
    content = function(file) {
      tryCatch({
        write.csv(rv$cl_log, file, row.names = FALSE, fileEncoding = "UTF-8")
      }, error = function(e) {
        write.csv(data.frame(Error = e$message), file, row.names = FALSE)
      })
    })
  
  output$dl_final_cleaned <- downloadHandler(
    filename = function() paste0("odqa_cleaned_", format(Sys.time(), "%Y%m%d_%H%M"), ".csv"),
    content = function(file) {
      tryCatch({
        d <- rv$cl_data %||% rv$mapped
        if (!is.null(d)) {
          if (".row_id" %in% names(d)) d[[".row_id"]] <- NULL
          data.table::fwrite(d, file)
        } else {
          write.csv(data.frame(Info = "No data available"), file, row.names = FALSE)
        }
      }, error = function(e) {
        write.csv(data.frame(Error = e$message), file, row.names = FALSE)
      })
    })
  
} # end server

# ── Section 12: Launch ───────────────────────────────────────────────────────
shinyApp(ui = ui, server = server)



