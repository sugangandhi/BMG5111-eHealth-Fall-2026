import os
import shutil
from pptx import Presentation
from pptx.util import Inches

def embed_architecture_image_into_deck():
    ppt_path = "eHospital_Professional_Architecture_Slides.pptx"
    img_path = "eHospital_System_Architecture_HD.png"
    out_master = "eHospital_Production_Architecture_Master.pptx"
    
    if not os.path.exists(img_path):
        raise FileNotFoundError(f"Missing {img_path}")
        
    prs = Presentation(ppt_path)
    blank_layout = prs.slide_layouts[6]
    
    # Add picture spanning entire 16:9 widescreen slide (Slide 8 / Dedicated Diagram Slide)
    slide = prs.slides.add_slide(blank_layout)
    slide.shapes.add_picture(img_path, 0, 0, Inches(13.333), Inches(7.5))
    
    prs.save(out_master)
    print(f"Created Master Deck with Embedded 4K Architecture Diagram: {os.path.abspath(out_master)}")
    
    # Also copy PNG, SVG, and PPTX to Desktop and Downloads
    destinations = [
        "C:/Users/sugan/OneDrive/Desktop",
        "C:/Users/sugan/Downloads"
    ]
    files_to_copy = [
        "eHospital_System_Architecture_HD.png",
        "eHospital_System_Architecture.svg",
        "eHospital_Production_Architecture_Master.pptx"
    ]
    for d in destinations:
        if os.path.exists(d):
            for f in files_to_copy:
                try:
                    shutil.copy(f, os.path.join(d, f))
                    print(f"Copied {f} to {d}")
                except Exception as e:
                    print(f"Could not copy {f} to {d}: {e}")

if __name__ == "__main__":
    embed_architecture_image_into_deck()
