# Cogify

Conversion d'un GeoTIFF en Cloud Optimized GeoTIFF (COG), avec interface graphique.

## Installation (Windows)

1. Téléchargez ce dépôt (bouton **Code → Download ZIP** sur GitHub, ou `git clone`) et décompressez-le.
2. Double-cliquez sur **`install.bat`**.
   - Le script installe Miniconda automatiquement si nécessaire (silencieux, ~5 min la première fois).
   - Il crée un environnement Python dédié (`cogify`) avec GDAL et Streamlit.
   - Il crée un raccourci **Cogify** sur le bureau.
3. Une fois terminé, double-cliquez sur le raccourci **Cogify** sur le bureau pour lancer l'application.

## Utilisation

1. L'application s'ouvre dans votre navigateur.
2. Importez votre fichier GeoTIFF.
3. Choisissez le type de compression :
   - **JPEG** : pour les orthophotos RVB (avec perte, qualité réglable)
   - **LZW** : sans perte, pour les données thématiques ou MNE
4. Choisissez le nom du fichier de sortie et, optionnellement, un dossier de destination (bouton "Parcourir...").
5. Cliquez sur **Lancer la conversion**.

## Prérequis

- Windows 64-bit
- Connexion internet (pour l'installation initiale uniquement)

## Utilisation en ligne de commande

```
conda activate cogify
cd app
python cogify.py <input.tif> [output_cog.tif] --compression JPEG --quality 90
```

## Mise à jour

Téléchargez à nouveau le dépôt (ou `git pull`), puis relancez **Cogify** — pas besoin de réinstaller, sauf si `environment.yml` a changé (relancez alors `install.bat`).
