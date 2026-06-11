"""
cogify.py — Conversion d'un GeoTIFF en Cloud Optimized GeoTIFF (COG)
Usage : python cogify.py <input.tif> [output_cog.tif]

Paramètres ortho (calés sur les conventions SIT PMO) :
  COMPRESS=JPEG · JPEG_QUALITY=90 · PHOTOMETRIC=YCBCR (ortho RVB 3 bandes)
  OVERVIEW_RESAMPLING=BILINEAR · BLOCKSIZE=512 · NUM_THREADS=12 · BIGTIFF=YES
"""

import sys
import os
import argparse

# Import GDAL — gdal.UseExceptions() charge gdal_array qui requiert NumPy 1.x ;
# on l'active uniquement si l'import réussit pour éviter le crash sur NumPy 2.x.
try:
    from osgeo import gdal
    gdal.UseExceptions()
except Exception:
    from osgeo import gdal  # Import de base sans UseExceptions


def cogify(input_path: str, output_path: str = None, compression: str = "JPEG", jpeg_quality: int = 90, progress_callback=None) -> str:
    """
    Convertit un GeoTIFF en COG avec compression JPEG (quality 90) ou LZW, tuiles 512x512 et 12 threads.
    PHOTOMETRIC=YCBCR automatique si JPEG + 3 bandes RVB. Retourne le chemin du fichier de sortie.
    compression : "JPEG" (défaut, ortho RVB) ou "LZW" (sans perte, données thématiques/MNE)
    """

    # Chemin de sortie par défaut : même dossier, suffixe _cog.tif
    if output_path is None:
        base = os.path.splitext(input_path)[0]
        output_path = f"{base}_cog.tif"

    print(f"[cogify] Entrée  : {input_path}")
    print(f"[cogify] Sortie  : {output_path}")

    # Vérification de l'existence du fichier source
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Fichier introuvable : {input_path}")

    # Détection du nombre de bandes pour choisir PHOTOMETRIC
    ds_src = gdal.Open(input_path)
    if ds_src is None:
        raise FileNotFoundError(f"Impossible d'ouvrir : {input_path}")
    nb_bandes = ds_src.RasterCount
    ds_src = None

    compression = compression.upper()
    print(f"[cogify] Compression : {compression}")

    if compression == "JPEG":
        # PHOTOMETRIC=YCBCR uniquement sur ortho RVB stricte (3 bandes) — bien plus efficace
        # Sur 4 bandes (RVBA) ou autre, YCBCR n'est pas supporté
        photometric = "YCBCR" if nb_bandes == 3 else "MINISBLACK"
        creation_options = [
            "COMPRESS=JPEG",                 # Compression avec perte, bien plus efficace que LZW sur orthos RVB
            f"QUALITY={jpeg_quality}",       # Qualité JPEG (90 = bon compromis qualité/poids) — option COG, pas JPEG_QUALITY
            f"PHOTOMETRIC={photometric}",    # YCBCR si 3 bandes RVB, sinon MINISBLACK
            "BLOCKSIZE=512",
            "OVERVIEW_RESAMPLING=BILINEAR",
            "NUM_THREADS=12",
            "BIGTIFF=YES",
        ]
    else:  # LZW
        creation_options = [
            "COMPRESS=LZW",                  # Compression sans perte, pour données thématiques ou MNE
            "PREDICTOR=2",                   # Différentiel horizontal — réduit le poids sur valeurs continues
            "BLOCKSIZE=512",
            "OVERVIEW_RESAMPLING=BILINEAR",
            "NUM_THREADS=12",
            "BIGTIFF=YES",
        ]

    # Options COG ortho — calées sur les conventions SIT PMO
    def _gdal_progress(complete, message, data):
        if progress_callback:
            progress_callback(complete)
        return 1

    options = gdal.TranslateOptions(
        format="COG",
        creationOptions=creation_options,
        callback=_gdal_progress,
    )

    # Conversion
    gdal.Translate(output_path, input_path, options=options)

    # Vérification COG (optionnelle mais recommandée)
    ds = gdal.Open(output_path)
    if ds is None:
        raise RuntimeError("Échec de la création du COG.")
    ds = None

    taille_mo = os.path.getsize(output_path) / (1024 * 1024)
    print(f"[cogify] ✓ COG généré ({taille_mo:.1f} Mo) : {output_path}")
    return output_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Conversion GeoTIFF → COG")
    parser.add_argument("input",  help="Fichier GeoTIFF source")
    parser.add_argument("output", nargs="?", default=None, help="Fichier COG de sortie (défaut : suffixe _cog.tif)")
    parser.add_argument("--compression", choices=["JPEG", "LZW"], default="JPEG",
                        help="Mode de compression : JPEG (ortho RVB, défaut) ou LZW (sans perte)")
    parser.add_argument("--quality", type=int, default=90,
                        help="Qualité JPEG (1-100, défaut : 90, ignoré en LZW)")
    args = parser.parse_args()

    cogify(args.input, args.output, compression=args.compression, jpeg_quality=args.quality)
