# Migration Oracle → PostgreSQL avec ora2pg — Projet MNT

> **Auteur :** Saad BRAHMIA — Senior DBA / Database SRE  
> **Date :** Juillet 2024  
> **Outil :** [ora2pg](https://ora2pg.darold.net/)  
> **Source :** Oracle (schéma `GEDMNT`)  
> **Cible :** PostgreSQL 15.7 — Ubuntu 20.04 (hébergé)  
> **Périmètre :** 40 tables · ~21,7 millions de lignes · Données uniquement (packages, procédures et triggers exclus)

## Sommaire

1. [Contexte et périmètre](#1-contexte-et-périmètre)
2. [Prérequis et évaluation initiale](#2-prérequis-et-évaluation-initiale)
3. [Initialisation du projet ora2pg](#3-initialisation-du-projet-ora2pg)
4. [Génération des DDL](#4-génération-des-ddl)
5. [Création de la base cible PostgreSQL](#5-création-de-la-base-cible-postgresql)
6. [Création des tables](#6-création-des-tables)
7. [Export des données depuis Oracle](#7-export-des-données-depuis-oracle)
8. [Import des données dans PostgreSQL](#8-import-des-données-dans-postgresql)
9. [Application des contraintes et index](#9-application-des-contraintes-et-index)
10. [Vérification post-migration](#10-vérification-post-migration)
11. [Problèmes rencontrés et corrections](#11-problèmes-rencontrés-et-corrections)
12. [Bilan et axes d'amélioration](#12-bilan-et-axes-d'amélioration)

## 1. Contexte et périmètre

Afin de conserver l'historique sous forme d'archive, la base de l'application, renommée MNT, pour des raisons de confidentialité, a fait l'objet d'une migration d'Oracle sous windows vers PostgreSQL sous ubuntu. L'effort s'est concentré exclusivement sur la couche données (tables, séquences, contraintes, index). Les objets PL/SQL, tels que les triggers, packages et procédures stockées, n'ont pas été migrés. 

| Paramètre | Valeur |
|---|---|
| Schéma Oracle source | `GEDMNT` |
| Base PostgreSQL cible | `mnt_db` |
| Schéma PostgreSQL | `mnt` |
| Nombre de tables | 40 |
| Volume total | ~21,7 M lignes |
| Durée totale (data export + import) | ~2h30 |
| Client ora2pg | Windows (poste de migration) |
| Serveur cible | PostgreSQL 15.7 / Ubuntu 20.04 — SSL TLSv1.3 |

## 2. Prérequis et évaluation initiale

Avant de lancer la migration, l'étape initiale consiste à installer et configurer l'outil Ora2Pg. Il est ensuite essentiel de générer le **rapport d'évaluation ora2pg**. Ce document permet d'estimer la complexité du schéma source.

```bash
ora2pg -t SHOW_REPORT --estimate_cost \
  -c E:\ora2pg\mig\MNT\config\ora2pg.conf \
  -o E:\ora2pg\mig\MNT\reports\report.html
```

Paramètres clés à configurer dans `ora2pg.conf` avant de démarrer :

```ini
# Encodage source Oracle
NLS_LANG             = AMERICAN_AMERICA.WE8MSWIN1252

# Exclure les artefacts Data Pump non applicatifs
EXCLUDE_TABLE        = SYS_EXPORT_TABLE_01

# Mapping de types personnalisé (eviter bigint sur NUMBER sans précision)
DATA_TYPE            = NUMBER:numeric

# Schéma cible
EXPORT_SCHEMA        = 1
SCHEMA               = GEDMNT
PG_SCHEMA            = mnt
```

## 3. Initialisation du projet

La commande `--init_project` permet de créer l'arborescence du projet de migration.

```bash
ora2pg --init_project MNT --project_base E:\ora2pg\mig
```

**Structure générée :**

```
E:\ora2pg\mig\MNT\
├── config\
│   └── ora2pg.conf          ← fichier de configuration principal
├── schema\
│   ├── tables\              ← DDL tables, contraintes, index
│   ├── sequences\           ← séquences Oracle → PostgreSQL
│   ├── sequence_values\     ← valeurs courantes des séquences
│   ├── views\
│   ├── functions\           ← hors périmètre (non migrés)
│   ├── procedures\          ← hors périmètre (non migrés)
│   ├── packages\            ← hors périmètre (non migrés)
│   ├── triggers\            ← hors périmètre (non migrés)
│   └── types\
├── data\                    ← scripts COPY générés
└── reports\                 ← rapport SHOW_REPORT
```

## 4. Génération des DDL

### 4.1 Export des tables

```bash
ora2pg -p -t TABLE \
  -o table.sql \
  -b E:\ora2pg\mig\MNT\schema\tables \
  -c E:\ora2pg\mig\MNT\config\ora2pg.conf
```

**Sortie :**

```
[2024-07-10 09:38:23] [========================>] 40/40 tables (100.0%) end of scanning.
[2024-07-10 09:38:38] [========================>] 40/40 tables (100.0%) end of table export.
```

40 tables exportées en ~15 secondes.

### 4.2 Corrections manuelles post-export

Après génération, mettre à jour les fichiers `table.sql`, `CONSTRAINTS_table.sql` et `INDEXES_table.sql` :

**a) Encodage client**

ora2pg génère par défaut `SET client_encoding TO 'UTF8'`. Si la base Oracle source est en `WE8MSWIN1252`, remplacer dans les trois fichiers :

```sql
-- Remplacer :
SET client_encoding TO 'UTF8';
-- Par :
SET client_encoding TO 'WIN1252';
```

> **Note :** Il est préconisé de configurer `NLS_LANG` dans `ora2pg.conf` avant l'export. 

**b) Vérification des mappings de types**

Contrôler les colonnes `NUMBER` Oracle sans précision — ora2pg peut les mapper en `bigint`, ce qui provoque des erreurs à l'import si la colonne contient des décimaux. Corriger dans `table.sql` avant l'import.

**c) Exclure `SYS_EXPORT_TABLE_01`**

Cette table est un artefact du Data Pump Oracle (`expdp`), sans valeur applicative. La supprimer du DDL ou l'exclure via `EXCLUDE_TABLE` dans `ora2pg.conf`.

### 4.3 Export des séquences

Ne pas oublier d'exporter les séquences et leurs valeurs courantes — étape souvent omise, critique pour éviter les conflits de clés primaires après reprise applicative.

Les séquences n'ont pas été migrées dans ce projet : la base PostgreSQL cible étant destinée à un usage archivage en lecture seule, aucune reprise applicative n'est prévue et les valeurs courantes des séquences ne présentent donc pas d'intérêt opérationnel.

Les commandes ci-dessus sont conservées à titre de référence pour les migrations avec reprise applicative active.

```bash
# Définitions des séquences
ora2pg -p -t SEQUENCE \
  -o sequence.sql \
  -b E:\ora2pg\mig\MNT\schema\sequences \
  -c E:\ora2pg\mig\MNT\config\ora2pg.conf

# Valeurs courantes (LAST_NUMBER)
ora2pg -p -t SEQUENCE_VALUES \
  -o sequence_values.sql \
  -b E:\ora2pg\mig\MNT\schema\sequence_values \
  -c E:\ora2pg\mig\MNT\config\ora2pg.conf
```

## 5. Création de la base cible PostgreSQL

```sql
-- Création du rôle mnt_user
CREATE ROLE mnt_user LOGIN PASSWORD '<mot_de_passe_fort>';

-- Création de la base
CREATE DATABASE mnt_db OWNER mnt_user;

-- Connexion à la base
\c mnt_db

-- Création du schéma applicatif
CREATE SCHEMA mnt AUTHORIZATION mnt_user;

-- search_path par défaut
ALTER ROLE mnt_user SET search_path = mnt, public;

REVOKE ALL ON SCHEMA public FROM PUBLIC;
```

> **Remarques :**
> - Utiliser `ALTER ROLE ... SET search_path` plutôt qu'un `SET` de session, pour que le paramètre soit persistant.
> - Ne jamais stocker le mot de passe en clair dans les scripts. Utiliser `.pgpass` pour les appels psql automatisés.

**Vérification de la connexion :**

```
psql (16.0, server 15.7 (Ubuntu 15.7-1.pgdg20.04+1))
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, compression: off)
mnt_db=>
```

## 6. Création des tables

L'ordre d'exécution est important : tables d'abord, données ensuite, contraintes et index en dernier.

```bash
time /t && psql -h <host> -d mnt_db -U mnt_user \
  -f E:\ora2pg\mig\MNT\schema\tables\table.sql \
  -o E:\ora2pg\mig\MNT\schema\tables\table.log && time /t
```

**Vérification — 40 tables créées dans le schéma `mnt` :**

```sql
mnt_db=> \dt mnt.*
```

```
 Schema |             Name              | Type  |  Owner
--------+-------------------------------+-------+----------
 mnt    | gedmnt_checkpoint_types       | table | mnt_user
 mnt    | gedmnt_chkpttype_wartype      | table | mnt_user
 mnt    | gedmnt_clauses                | table | mnt_user
 mnt    | gedmnt_contract_types         | table | mnt_user
 mnt    | gedmnt_data_types             | table | mnt_user
 mnt    | gedmnt_departement            | table | mnt_user
 mnt    | gedmnt_documents              | table | mnt_user
 mnt    | gedmnt_event_datas            | table | mnt_user
 mnt    | gedmnt_event_types            | table | mnt_user
 mnt    | gedmnt_events                 | table | mnt_user
 ...
 (40 rows)
```

## 7. Export des données depuis Oracle

Le mode `COPY` a été utilisé pour des raisons de performances.

```bash
time /t && ora2pg -p -t COPY \
  -o data.sql \
  -b F:\ora2pg\mig\MNT\data\tables \
  -c E:\ora2pg\mig\MNT\config\ora2pg.conf && time /t
```

**Résultats de l'export :**

| Heure début | Heure fin | Durée | Lignes exportées | Débit moyen |
|---|---|---|---|---|
| 09:29 | 10:49 | ~1h20 | 21 769 898 | ~4 653 recs/sec |

**Tables volumineuses :**

| Table | Lignes | Débit |
|---|---|---|
| `GEDMNT_EVENT_DATAS` | 19 743 218 | 56 733 recs/sec |
| `GEDMNT_SAPHR` | 393 807 | 9 845 recs/sec |
| `GEDMNT_WARNINGS` | 455 132 | 23 954 recs/sec |
| `GEDMNT_DOCUMENTS` | 602 518 | 143 recs/sec |

> **Remarque sur les compteurs > 100% :** ora2pg estime le nombre de lignes à partir des statistiques Oracle (`DBA_TABLES.NUM_ROWS`), pas d'un `COUNT(*)` exact. Un écart jusqu'à ~2% est normal si les statistiques ne sont pas fraîches. Vérifier les comptes exacts après import (voir section 10).

## 8. Import des données dans PostgreSQL

### 8.1 Préparation du fichier data.sql

**a) Activer l'arrêt sur erreur**

Ajouter en tête du fichier `data.sql` :

```sql
\set ON_ERROR_STOP ON
```

Sans cette directive, psql continue silencieusement malgré les erreurs, rendant le débogage difficile.

**b) Corriger les chemins Windows**

Le fichier `data.sql` contient des chemins avec des backslashes (`\`) que psql interprète mal. Les remplacer par des slashes forward (`/`) :

```
F:\ora2pg\mig\MNT\data\tables\GEDMNT_CHECKPOINT_TYPES_data.sql
→
F:/ora2pg/mig/MNT/data/tables/GEDMNT_CHECKPOINT_TYPES_data.sql
```

> **Alternative :** exécuter le remplacement via PowerShell pour éviter l'édition manuelle :
> ```powershell
> (Get-Content data.sql) -replace '\\', '/' | Set-Content data.sql
> ```

### 8.2 Lancement de l'import

```bash
time /t && psql -h <host> -d mnt_db -U mnt_user \
  -f F:\ora2pg\mig\MNT\data\tables\data.sql \
  -o F:\ora2pg\mig\MNT\data\tables\data.log && time /t
```

**Durée d'import :** 04:01 PM → 04:56 PM — **~55 minutes**

## 9. Application des contraintes et index

### 9.1 Contraintes

```bash
time /t && psql -h <host> -d mnt_db -U mnt_user \
  -f E:\ora2pg\mig\MNT\schema\tables\CONSTRAINTS_table.sql \
  -o E:\ora2pg\mig\MNT\schema\tables\CONSTRAINTS_table.log && time /t
```

### 9.2 Index

```bash
time /t && psql -h <host> -d mnt_db -U mnt_user \
  -f E:\ora2pg\mig\MNT\schema\tables\INDEXES_table.sql \
  -o E:\ora2pg\mig\MNT\schema\tables\INDEXES_table.log && time /t
```

## 10. Vérification post-migration

### 10.1 Comparaison des counts Oracle vs PostgreSQL

Après la migration, une vérification du nombre d'objets (tables, indexes, contraintes) ainsi que le nombre de lignes dans chaque table a été effectué dans Oracle et PostgreSQL.

Coté Oracle:
Nombre  d'objets:
```sql
SELECT
    (SELECT COUNT(*)
     FROM all_tables
     WHERE owner = 'GEDMNT') AS nb_tables,

    (SELECT COUNT(*)
     FROM all_constraints
     WHERE owner = 'GEDMNT') AS nb_contraintes,

    (SELECT COUNT(*)
     FROM all_indexes
     WHERE owner = 'GEDMNT') AS nb_index
FROM dual;
```
Nombre de lignes:
```sql
SET SERVEROUTPUT ON SIZE UNLIMITED;
DECLARE
    v_table_count INTEGER := 0;
    v_owner       VARCHAR2(30) := 'GEDMNT';
BEGIN
    FOR r IN (
        SELECT table_name 
        FROM all_tables
        WHERE owner = v_owner
          AND nested = 'NO' 
          AND secondary = 'N'
          AND (iot_type IS NULL OR iot_type != 'IOT_OVERFLOW')
        ORDER BY table_name
    ) 
    LOOP
        EXECUTE IMMEDIATE 'SELECT count(*) FROM ' || DBMS_ASSERT.ENQUOTE_NAME(v_owner) 
                          || '.' || DBMS_ASSERT.ENQUOTE_NAME(r.table_name)
        INTO v_table_count;
        
        DBMS_OUTPUT.PUT_LINE('Table ' || v_owner || '.' || r.table_name || ' = ' || v_table_count || ' lignes');
        
    END LOOP;
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erreur rencontrée : ' || SQLERRM);
END;
/
```
Coté PostgreSQL:
Nombre d'objets:
```sql
SELECT
    (SELECT COUNT(*)
     FROM information_schema.tables
     WHERE table_schema = 'mnt'
       AND table_type = 'BASE TABLE') AS nb_tables,

    (SELECT COUNT(*)
     FROM pg_constraint con
     JOIN pg_namespace n
       ON n.oid = con.connamespace
     WHERE n.nspname = 'mnt') AS nb_contraintes,

    (SELECT COUNT(*)
     FROM pg_indexes
     WHERE schemaname = 'mnt') AS nb_index;
```
Nombre de lignes
```sql
DO $$
<<first_block>>
DECLARE
    table_count integer := 0;
    target_schema text := 'mnt';
    r RECORD;
BEGIN
    FOR r IN
        SELECT c.relname AS table_name
        FROM pg_class AS c
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = target_schema
          AND NOT EXISTS (SELECT 1 FROM pg_inherits AS i WHERE i.inhrelid = c.oid)
          AND c.relkind IN ('r', 'p')
        ORDER BY c.relname
    LOOP
        EXECUTE format('SELECT count(*) FROM %I.%I', target_schema, r.table_name)
        INTO table_count;
        RAISE NOTICE 'Table %.% = % lignes', target_schema, r.table_name, table_count;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Erreur : %', SQLERRM;
END first_block $$;
```

## 11. Problèmes rencontrés et corrections

### Problème 1 — Encodage WIN1252

**Symptôme :** `WARNING: Console code page (437) differs from Windows code page (1252)` — risque de corruption silencieuse des caractères spéciaux.

**Cause :** ora2pg génère `SET client_encoding TO 'UTF8'` alors que la source Oracle est en `WE8MSWIN1252`.

**Correction appliquée :** remplacement manuel de l'encodage dans les fichiers DDL + sauvegarde en ANSI.

**Correction recommandée:**

```ini
# Dans ora2pg.conf
NLS_LANG = AMERICAN_AMERICA.WE8MSWIN1252
```

Cela permet à ora2pg de transcrire les données vers UTF-8 à l'export, et la base PostgreSQL reste en UTF-8 nativement.

---

### Problème 2 — Erreur de type `bigint` sur colonne décimale

**Symptôme :**

```
ERROR:  invalid input syntax for type bigint: ".1817"
CONTEXT:  COPY sys_export_table_01, line 193, column dump_allocation: ".1817"
```

**Cause :** ora2pg a mappé la colonne Oracle `NUMBER` (sans précision explicite) en `bigint`. Or la colonne contient des valeurs décimales.

**Correction appliquée :** modification du type dans `table.sql` de `bigint` à `double precision`.

**Correction recommandée :** auditer tous les mappings `NUMBER` dans `table.sql` avant l'import :

Et configurer dans `ora2pg.conf` :

```ini
# Mapper NUMBER sans précision en numeric plutôt qu'en bigint
DATA_TYPE = NUMBER:numeric
```

### Problème 3 — Table `SYS_EXPORT_TABLE_01` migrée par erreur

**Cause :** cette table est un artefact du Data Pump Oracle (`expdp`), présente dans le schéma source mais sans valeur applicative.

**Correction appliquée :** suppression post-migration.

**Correction recommandée :**

```ini
# Dans ora2pg.conf
EXCLUDE_TABLE = SYS_EXPORT_TABLE_01
```

### Problème 4 — Chemins Windows dans data.sql

**Symptôme :** psql ne retrouve pas les fichiers de données référencés avec des backslashes.

**Correction appliquée :** remplacement manuel `\` → `/` dans `data.sql`.

**Correction recommandée :** automatiser via PowerShell (voir section 8.1).


## 12. Bilan et axes d'amélioration

### Synthèse de la migration

| Étape | Statut | Durée |
|---|---|---|
| Initialisation projet | ✅ | < 1 min |
| Export DDL (40 tables) | ✅ | ~15 sec |
| Création base PostgreSQL | ✅ | < 1 min |
| Création tables | ✅ | < 1 min |
| Export données Oracle | ✅ | ~1h20 |
| Import données PostgreSQL | ✅ | ~55 min |
| Contraintes + index | ✅ | < 1 min |
| **Total** | **✅** | **~2h30** |

### Ce qui a bien fonctionné

- Respect de l'ordre canonique ora2pg (DDL → data → contraintes → index)
- Utilisation du mode `COPY` (plus performant qu'`INSERT`)
- Activation de `\set ON_ERROR_STOP ON`
- Débit global satisfaisant (~4 650 recs/sec en moyenne sur 21,7 M lignes via SSL)

### Axes d'amélioration avant la migration de la base de 2,5To

| Point | Action recommandée |
|---|---|
| Encodage | Configurer `NLS_LANG` dans `ora2pg.conf` — ne pas corriger manuellement |
| Mapping de types | Auditer `table.sql` et utiliser `DATA_TYPE = NUMBER:numeric` |
| Artefacts Oracle | Utiliser `EXCLUDE_TABLE` pour filtrer les tables non applicatives |
| Vérification counts | Comparer Oracle vs PostgreSQL sur toutes les tables post-import |

> **Environnement :** ora2pg · Oracle 19c · PostgreSQL 15.7 · Windows · Ubuntu 20.04
> **Repo :** [github.com/Saad7478](https://github.com/Saad7478)
