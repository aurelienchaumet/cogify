"""
app.py — Interface Streamlit pour cogify
Usage : streamlit run app.py
"""

import os
import tempfile
import streamlit as st
import tkinter as tk
from tkinter import filedialog

from cogify import cogify

st.set_page_config(page_title="Cogify — GeoTIFF → COG", page_icon="🗺️", layout="centered")

st.title("🗺️ Cogify")
st.caption("Conversion d'un GeoTIFF en Cloud Optimized GeoTIFF (COG)")

uploaded_file = st.file_uploader("Fichier GeoTIFF source", type=["tif", "tiff"])

compression = st.radio(
    "Compression",
    options=["JPEG", "LZW"],
    captions=[
        "Ortho RVB (avec perte, YCBCR si 3 bandes)",
        "Sans perte (données thématiques / MNE)",
    ],
    horizontal=True,
)

jpeg_quality = 90
if compression == "JPEG":
    jpeg_quality = st.slider("Qualité JPEG", min_value=1, max_value=100, value=90,
                              help="Plus élevé = meilleure qualité mais fichier plus lourd")

default_name = ""
if uploaded_file is not None:
    default_name = f"{os.path.splitext(uploaded_file.name)[0]}_cog.tif"

output_name = st.text_input("Nom du fichier COG de sortie", value=default_name)

if "output_dir_picked" not in st.session_state:
    st.session_state.output_dir_picked = ""

col1, col2 = st.columns([4, 1])
with col1:
    output_dir = st.text_input("Dossier de destination", value=st.session_state.output_dir_picked,
                                placeholder=r"Ex : D:\Documents\Projets\ia\cogify\sorties")
with col2:
    st.write("")
    st.write("")
    if st.button("Parcourir..."):
        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        chosen = filedialog.askdirectory()
        root.destroy()
        if chosen:
            st.session_state.output_dir_picked = chosen
            st.rerun()

if uploaded_file is not None:
    if st.button("Lancer la conversion", type="primary"):
        if not output_name:
            st.error("Merci de renseigner un nom de fichier de sortie.")
        elif output_dir and not os.path.isdir(output_dir):
            st.error(f"Le dossier de destination n'existe pas : {output_dir}")
        else:
            with tempfile.TemporaryDirectory() as tmpdir:
                input_path = os.path.join(tmpdir, uploaded_file.name)
                with open(input_path, "wb") as f:
                    f.write(uploaded_file.getbuffer())

                final_name = output_name if output_name.lower().endswith((".tif", ".tiff")) else f"{output_name}.tif"

                if output_dir:
                    output_path = os.path.join(output_dir, final_name)
                else:
                    output_path = os.path.join(tmpdir, final_name)

                progress_bar = st.progress(0, text="Conversion en cours... 0%")

                def update_progress(fraction):
                    pct = int(fraction * 100)
                    progress_bar.progress(fraction, text=f"Conversion en cours... {pct}%")

                try:
                    cogify(input_path, output_path, compression=compression,
                           jpeg_quality=jpeg_quality, progress_callback=update_progress)
                except Exception as e:
                    st.error(f"Échec de la conversion : {e}")
                else:
                    progress_bar.progress(1.0, text="Conversion terminée")
                    taille_mo = os.path.getsize(output_path) / (1024 * 1024)
                    st.success(f"COG généré ({taille_mo:.1f} Mo)")
                    if output_dir:
                        st.info(f"Fichier enregistré : {output_path}")
                    else:
                        with open(output_path, "rb") as f:
                            st.download_button(
                                "Télécharger le COG",
                                data=f.read(),
                                file_name=final_name,
                                mime="image/tiff",
                            )
