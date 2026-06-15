-- =============================================================
-- PRÉREQUIS : exécuter en tant que superuser (ex: postgres)
-- =============================================================

-- Création du rôle
CREATE ROLE mnt_user LOGIN PASSWORD '<mot_de_passe_fort>';

-- Création de la base de données
CREATE DATABASE mnt_db OWNER mnt_user;

-- Connexion à la base mnt_db
\c mnt_db

-- Création du schéma
CREATE SCHEMA mnt AUTHORIZATION mnt_user;

-- search_path scopé à mnt_db uniquement
ALTER ROLE mnt_user IN DATABASE mnt_db SET search_path = mnt;

-- Sécurisation du schéma public
REVOKE ALL ON SCHEMA public FROM PUBLIC;
