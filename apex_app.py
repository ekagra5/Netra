"""
Netra: bilingual retinal screening app for local TFLite inference.
"""

import base64
import datetime as dt
import html
import io
import math
from pathlib import Path

import cv2
import numpy as np
import streamlit as st
from PIL import Image

try:
    from tflite_runtime.interpreter import Interpreter
except ImportError:
    import tensorflow as tf

    Interpreter = tf.lite.Interpreter


APP_DIR = Path(__file__).resolve().parent
MODEL_PATH = APP_DIR / "model_apex_v2.tflite"
IMG_SIZE = 224
OCULAR_THRESHOLD = 0.5
LOW_CONFIDENCE_THRESHOLD = 0.45
CLOSE_MARGIN_THRESHOLD = 0.10

DR_CLASSES = [
    {"en": "No DR", "hi": "DR नहीं", "short_en": "No DR", "short_hi": "नहीं"},
    {"en": "Mild Non-Proliferative DR", "hi": "हल्का Non-Proliferative DR", "short_en": "Mild", "short_hi": "हल्का"},
    {"en": "Moderate Non-Proliferative DR", "hi": "मध्यम Non-Proliferative DR", "short_en": "Moderate", "short_hi": "मध्यम"},
    {"en": "Severe Non-Proliferative DR", "hi": "गंभीर Non-Proliferative DR", "short_en": "Severe", "short_hi": "गंभीर"},
    {"en": "Proliferative DR", "hi": "Proliferative DR", "short_en": "PDR", "short_hi": "PDR"},
]

DME_CLASSES = [
    {"en": "No macular swelling risk", "hi": "मैकुलर सूजन का जोखिम नहीं", "short_en": "No risk", "short_hi": "जोखिम नहीं"},
    {"en": "Some macular swelling risk", "hi": "मैकुलर सूजन का कुछ जोखिम", "short_en": "Some risk", "short_hi": "कुछ जोखिम"},
    {"en": "High macular swelling risk", "hi": "मैकुलर सूजन का अधिक जोखिम", "short_en": "High risk", "short_hi": "अधिक जोखिम"},
]

OCULAR_ORDER = ["N", "D", "G", "C", "A", "H", "M", "O"]
OCULAR_REPORT = ["G", "C", "A", "H", "M", "O"]
OCULAR_NAMES = {
    "G": {"en": "Glaucoma", "hi": "ग्लूकोमा"},
    "C": {"en": "Cataract", "hi": "मोतियाबिंद"},
    "A": {"en": "Age-related macular degeneration", "hi": "उम्र से जुड़ी मैकुलर समस्या"},
    "H": {"en": "Hypertension signs", "hi": "उच्च रक्तचाप से जुड़े संकेत"},
    "M": {"en": "Myopia signs", "hi": "मायोपिया से जुड़े संकेत"},
    "O": {"en": "Other findings", "hi": "अन्य संकेत"},
}

TEXT = {
    "en": {
        "retinal": "Retinal screening",
        "made_for": "Local TFLite analysis",
        "operator": "Operator",
        "center": "Primary Health Center",
        "analyze": "Analyze",
        "report": "Report",
        "model_notes": "Model Notes",
        "help": "Help",
        "lang": "Language",
        "status": "Model status",
        "status_loaded": "New local model ready",
        "status_missing": "Model file missing",
        "accuracy_note": "Measured 45.6% exact DR grade accuracy on 103 IDRiD test images.",
        "analyze_title": "Analyze retinal image",
        "analyze_subtitle": "Upload a fundus image or capture one with the device camera.",
        "patient": "Patient details",
        "patient_id": "Patient ID",
        "patient_name": "Name",
        "age": "Age",
        "sex": "Sex",
        "optional": "Optional",
        "select_image": "Select image",
        "upload_tab": "Upload",
        "camera_tab": "Camera",
        "upload_label": "Upload JPG or PNG",
        "camera_label": "Capture retinal photo",
        "enable_camera": "Enable camera",
        "camera_waiting": "Camera is off until you enable it.",
        "preview": "Image preview",
        "ready": "Ready for analysis",
        "no_image": "Add an image to begin.",
        "run": "Run analysis",
        "heatmap_option": "Include explainability heatmap",
        "heatmap_help": "Adds occlusion sensitivity. It is useful, but slower.",
        "analysis": "Clinical summary",
        "empty_summary": "Results will appear here after analysis.",
        "dr_grade": "Diabetic retinopathy grade",
        "dme": "Macular swelling risk",
        "other": "Other eye findings",
        "confidence": "Confidence",
        "probability": "Probability",
        "grade": "Grade",
        "risk": "Risk",
        "finding": "Finding",
        "likelihood": "Likelihood",
        "flagged": "Flagged",
        "not_flagged": "Not flagged",
        "verification": "Verification notes",
        "good_quality": "Photo accepted for model inference. Confirm serious findings clinically.",
        "low_conf": "Confidence is low. Retake the image or request manual review.",
        "close_margin": "Top grades are close. Treat this as borderline.",
        "disclaimer": "Screening aid only. It is not a medical diagnosis.",
        "report_title": "Patient report",
        "report_empty": "No completed analysis yet. Run an analysis first.",
        "download": "Download report",
        "exam": "Exam",
        "recommendation": "Recommendation",
        "recommend_0": "Routine yearly eye check-up is reasonable if symptoms are absent.",
        "recommend_1": "Repeat screening or refer for routine ophthalmology review.",
        "recommend_2": "Ophthalmology review is recommended within 3 months.",
        "recommend_3": "Refer to an eye specialist within a few weeks.",
        "recommend_4": "Urgent specialist review is advised.",
        "model_title": "Model notes",
        "model_body": "This app runs the new local TFLite model trained from the final fine-tuned Keras checkpoint. It predicts DR grade, DME risk, and six displayed ocular findings.",
        "metric_truth": "Training numbers are not real accuracy. The local held-out IDRiD test result is the honest reference currently available.",
        "help_title": "Capture guidance",
        "help_1": "Use a clear retinal fundus image with the optic disc and macula visible.",
        "help_2": "Avoid glare, blur, eyelids, heavy darkness, and off-center framing.",
        "help_3": "Run analysis again after retaking the image if the confidence note asks for review.",
        "footer": "created by team apex",
        "last_updated": "Last result",
        "full_report": "Full report",
        "summary": "Summary",
        "all_probs": "All probabilities",
        "heatmap": "Explainability heatmap",
        "heatmap_caption": "Warmer areas had more effect on the predicted DR grade.",
        "not_available": "Not available",
        "normal": "Normal",
        "possible": "Possible",
        "high": "High",
    },
    "hi": {
        "retinal": "रेटिना स्क्रीनिंग",
        "made_for": "लोकल TFLite विश्लेषण",
        "operator": "ऑपरेटर",
        "center": "प्राथमिक स्वास्थ्य केंद्र",
        "analyze": "विश्लेषण",
        "report": "रिपोर्ट",
        "model_notes": "मॉडल नोट्स",
        "help": "सहायता",
        "lang": "भाषा",
        "status": "मॉडल स्थिति",
        "status_loaded": "नया लोकल मॉडल तैयार है",
        "status_missing": "मॉडल फाइल नहीं मिली",
        "accuracy_note": "103 IDRiD टेस्ट इमेज पर exact DR grade accuracy 45.6% मापी गई।",
        "analyze_title": "रेटिना इमेज का विश्लेषण",
        "analyze_subtitle": "फंडस इमेज अपलोड करें या डिवाइस कैमरा से कैप्चर करें।",
        "patient": "मरीज विवरण",
        "patient_id": "मरीज ID",
        "patient_name": "नाम",
        "age": "उम्र",
        "sex": "लिंग",
        "optional": "वैकल्पिक",
        "select_image": "इमेज चुनें",
        "upload_tab": "अपलोड",
        "camera_tab": "कैमरा",
        "upload_label": "JPG या PNG अपलोड करें",
        "camera_label": "रेटिना फोटो कैप्चर करें",
        "enable_camera": "कैमरा चालू करें",
        "camera_waiting": "कैमरा तब तक बंद रहेगा जब तक आप इसे चालू नहीं करते।",
        "preview": "इमेज प्रीव्यू",
        "ready": "विश्लेषण के लिए तैयार",
        "no_image": "शुरू करने के लिए इमेज जोड़ें।",
        "run": "विश्लेषण शुरू करें",
        "heatmap_option": "Explainability heatmap शामिल करें",
        "heatmap_help": "Occlusion sensitivity जोड़ता है। उपयोगी है, पर धीमा है।",
        "analysis": "क्लिनिकल सारांश",
        "empty_summary": "विश्लेषण के बाद परिणाम यहां दिखेंगे।",
        "dr_grade": "डायबिटिक रेटिनोपैथी ग्रेड",
        "dme": "मैकुलर सूजन जोखिम",
        "other": "अन्य आंख संकेत",
        "confidence": "विश्वास",
        "probability": "संभावना",
        "grade": "ग्रेड",
        "risk": "जोखिम",
        "finding": "संकेत",
        "likelihood": "संभावना",
        "flagged": "चिह्नित",
        "not_flagged": "चिह्नित नहीं",
        "verification": "जांच नोट्स",
        "good_quality": "मॉडल inference के लिए फोटो स्वीकार हुई। गंभीर संकेतों की क्लिनिकल पुष्टि करें।",
        "low_conf": "विश्वास कम है। इमेज दोबारा लें या मैनुअल समीक्षा कराएं।",
        "close_margin": "ऊपर के ग्रेड करीब हैं। इसे borderline मानें।",
        "disclaimer": "यह केवल स्क्रीनिंग सहायता है। यह मेडिकल diagnosis नहीं है।",
        "report_title": "मरीज रिपोर्ट",
        "report_empty": "अभी कोई पूरा विश्लेषण नहीं है। पहले विश्लेषण चलाएं।",
        "download": "रिपोर्ट डाउनलोड करें",
        "exam": "जांच",
        "recommendation": "सलाह",
        "recommend_0": "लक्षण न हों तो सालाना आंख जांच उचित है।",
        "recommend_1": "दोबारा स्क्रीनिंग या routine ophthalmology review करें।",
        "recommend_2": "3 महीने के अंदर ophthalmology review की सलाह है।",
        "recommend_3": "कुछ हफ्तों के अंदर आंख विशेषज्ञ को दिखाएं।",
        "recommend_4": "तुरंत specialist review की सलाह है।",
        "model_title": "मॉडल नोट्स",
        "model_body": "यह ऐप final fine-tuned Keras checkpoint से बने नए local TFLite model को चलाता है। यह DR grade, DME risk, और छह ocular findings बताता है।",
        "metric_truth": "Training numbers real accuracy नहीं होते। अभी local held-out IDRiD test result ही ईमानदार reference है।",
        "help_title": "कैप्चर गाइड",
        "help_1": "स्पष्ट retinal fundus image लें जिसमें optic disc और macula दिखें।",
        "help_2": "glare, blur, eyelids, ज्यादा अंधेरा, और off-center framing से बचें।",
        "help_3": "यदि confidence note review मांगे तो image दोबारा लेकर analysis चलाएं।",
        "footer": "created by team apex",
        "last_updated": "अंतिम परिणाम",
        "full_report": "पूरी रिपोर्ट",
        "summary": "सारांश",
        "all_probs": "सभी probabilities",
        "heatmap": "Explainability heatmap",
        "heatmap_caption": "गर्म रंग वाले हिस्सों ने predicted DR grade पर अधिक असर डाला।",
        "not_available": "उपलब्ध नहीं",
        "normal": "सामान्य",
        "possible": "संभावित",
        "high": "अधिक",
    },
}


def tr(key):
    return TEXT[st.session_state.language][key]


def pct(value):
    return f"{value * 100:.1f}%"


def esc(value):
    return html.escape(str(value))


def set_defaults():
    defaults = {
        "language": "en",
        "page": "analyze",
        "latest_result": None,
        "camera_enabled": False,
        "image_source": "upload",
        "patient_id": "",
        "patient_name": "",
        "patient_age": "",
        "patient_sex": "",
    }
    for key, value in defaults.items():
        st.session_state.setdefault(key, value)


def apply_css():
    st.markdown(
        """
        <style>
            :root {
                --bg: #ffffff;
                --paper: #ffffff;
                --soft: #f6f8fa;
                --soft-2: #eef3f4;
                --line: #dce3e6;
                --line-strong: #c9d4d8;
                --ink: #101418;
                --muted: #69747c;
                --faint: #8b969d;
                --teal: #0a8a87;
                --teal-2: #076b69;
                --green: #17895a;
                --amber: #c77d00;
                --red: #bf3f3f;
                --blue: #2e6fa6;
                --shadow: 0 18px 45px rgba(12, 25, 31, 0.08);
                color-scheme: light;
            }

            .stApp { background: var(--bg); color: var(--ink); }
            .block-container {
                max-width: 1320px;
                padding: 24px 34px 48px;
            }
            html, body, [class*="css"], p, div, span, label {
                font-family: Inter, ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                color: var(--ink);
                letter-spacing: 0;
            }
            h1, h2, h3 { letter-spacing: 0; }
            #MainMenu, footer, header[data-testid="stHeader"], [data-testid="stToolbar"] {
                visibility: hidden;
            }
            div[data-testid="stVerticalBlock"] { gap: 0.8rem; }
            section[data-testid="stSidebar"] {
                background: #f8fafb;
                border-right: 1px solid var(--line);
            }
            section[data-testid="stSidebar"] > div {
                padding: 26px 18px 34px;
            }
            [data-testid="stSidebar"] h3 {
                font-size: 1.05rem;
                margin-bottom: 18px;
            }
            [data-testid="stSidebar"] [role="radiogroup"] label {
                border-radius: 8px;
                padding: 11px 13px;
                margin-bottom: 7px;
                border: 1px solid transparent;
            }
            [data-testid="stSidebar"] [role="radiogroup"] label:has(input:checked) {
                background: #eaf6f5;
                border-color: #b9dddb;
            }
            [data-testid="stSidebar"] [data-testid="stMarkdownContainer"] p {
                font-size: 0.9rem;
            }
            .app-shell {
                padding: 0;
            }
            .topbar {
                display: flex;
                align-items: center;
                justify-content: space-between;
                gap: 18px;
                border-bottom: 1px solid var(--line);
                padding: 0 0 16px;
                margin-bottom: 22px;
            }
            .brand {
                display: flex;
                align-items: center;
                gap: 12px;
            }
            .brand-mark {
                width: 42px;
                height: 42px;
                border: 1px solid #b7dddb;
                border-radius: 50%;
                display: grid;
                place-items: center;
                color: var(--teal);
            }
            .brand-title {
                font-size: 1.18rem;
                line-height: 1;
                font-weight: 750;
                color: var(--teal-2);
                margin: 0;
            }
            .brand-subtitle {
                font-size: 0.85rem;
                color: var(--muted);
                margin: 4px 0 0;
            }
            .top-actions {
                display: flex;
                align-items: center;
                justify-content: flex-end;
                gap: 18px;
                text-align: right;
            }
            .facility {
                font-size: 0.82rem;
                color: var(--muted);
                line-height: 1.45;
            }
            .facility b {
                color: var(--ink);
                font-size: 0.9rem;
            }
            h1.page-title,
            .stMarkdown h1.page-title {
                font-size: 1.72rem !important;
                line-height: 1.1;
                font-weight: 760;
                margin: 0 0 7px;
                padding: 0;
            }
            .page-subtitle {
                font-size: 0.94rem;
                color: var(--muted);
                margin: 0 0 18px;
            }
            .section-label {
                font-size: 0.78rem;
                font-weight: 720;
                text-transform: uppercase;
                color: var(--muted);
                letter-spacing: 0.04em;
                margin-bottom: 9px;
            }
            .panel {
                background: var(--paper);
                border: 1px solid var(--line);
                border-radius: 8px;
                padding: 17px;
                box-shadow: var(--shadow);
            }
            .flat-panel {
                border: 1px solid var(--line);
                border-radius: 8px;
                padding: 18px;
                background: #fff;
            }
            .muted-panel {
                background: var(--soft);
                border: 1px solid var(--line);
                border-radius: 8px;
                padding: 14px 16px;
            }
            .upload-choice {
                min-height: 112px;
                border: 1px dashed var(--line-strong);
                border-radius: 8px;
                display: flex;
                align-items: center;
                justify-content: center;
                text-align: center;
                background: #fff;
                color: var(--muted);
            }
            .empty-summary {
                min-height: 206px;
                display: flex;
                flex-direction: column;
                justify-content: center;
                gap: 12px;
                background:
                    linear-gradient(180deg, rgba(10,138,135,0.05), rgba(10,138,135,0) 55%),
                    #ffffff;
            }
            .summary-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(118px, 1fr));
                gap: 8px;
            }
            .summary-chip {
                border: 1px solid var(--line);
                border-radius: 7px;
                padding: 10px;
                background: #fbfcfd;
                font-size: 0.78rem;
                color: var(--muted);
                line-height: 1.35;
                overflow-wrap: anywhere;
            }
            .metric-row {
                display: flex;
                align-items: center;
                justify-content: space-between;
                gap: 16px;
                border-bottom: 1px solid var(--line);
                padding: 13px 0;
            }
            .metric-row:last-child { border-bottom: 0; }
            .metric-name { font-weight: 650; font-size: 0.95rem; }
            .metric-note { color: var(--muted); font-size: 0.82rem; margin-top: 3px; }
            .score {
                font-variant-numeric: tabular-nums;
                font-weight: 740;
                color: var(--ink);
                white-space: nowrap;
            }
            .severity-scale {
                display: grid;
                grid-template-columns: repeat(5, 1fr);
                gap: 6px;
                margin-top: 16px;
            }
            .severity-step {
                height: 7px;
                border-radius: 4px;
                background: var(--soft-2);
            }
            .severity-step.active:nth-child(1), .tone-0 { background: var(--green); }
            .severity-step.active:nth-child(2), .tone-1 { background: #7c9b35; }
            .severity-step.active:nth-child(3), .tone-2 { background: var(--amber); }
            .severity-step.active:nth-child(4), .tone-3 { background: #d06724; }
            .severity-step.active:nth-child(5), .tone-4 { background: var(--red); }
            .big-grade {
                display: flex;
                align-items: center;
                gap: 16px;
            }
            .grade-dial {
                width: 86px;
                height: 86px;
                border-radius: 50%;
                display: grid;
                place-items: center;
                color: #fff;
                flex: 0 0 auto;
            }
            .grade-num {
                font-size: 1.7rem;
                font-weight: 780;
                line-height: 1;
            }
            .grade-caption {
                font-size: 0.72rem;
                color: rgba(255,255,255,0.86);
                text-align: center;
            }
            .headline {
                font-size: 1.2rem;
                line-height: 1.2;
                font-weight: 760;
                margin: 0 0 6px;
            }
            .body-copy {
                color: var(--muted);
                font-size: 0.92rem;
                line-height: 1.55;
                margin: 0;
            }
            .status-dot {
                width: 8px;
                height: 8px;
                display: inline-block;
                border-radius: 50%;
                margin-right: 8px;
                background: var(--green);
            }
            .status-dot.warn { background: var(--amber); }
            .status-dot.red { background: var(--red); }
            .finding-table {
                width: 100%;
                border-collapse: collapse;
                font-size: 0.9rem;
            }
            .finding-table th {
                text-align: left;
                font-size: 0.76rem;
                color: var(--muted);
                font-weight: 720;
                border-bottom: 1px solid var(--line);
                padding: 8px 0;
            }
            .finding-table td {
                border-bottom: 1px solid var(--line);
                padding: 10px 0;
                vertical-align: middle;
            }
            .finding-table tr:last-child td { border-bottom: 0; }
            .badge {
                display: inline-flex;
                align-items: center;
                border-radius: 999px;
                padding: 4px 9px;
                background: var(--soft);
                border: 1px solid var(--line);
                font-size: 0.76rem;
                font-weight: 680;
                color: var(--muted);
                white-space: nowrap;
            }
            .badge.flag { color: #7b4800; background: #fff6df; border-color: #ead6a7; }
            .note-list {
                margin: 0;
                padding-left: 18px;
            }
            .note-list li {
                color: var(--muted);
                line-height: 1.5;
                margin-bottom: 6px;
            }
            .image-frame {
                border: 1px solid var(--line);
                border-radius: 8px;
                overflow: hidden;
                background: #f8fafb;
            }
            .report-head {
                display: flex;
                align-items: flex-start;
                justify-content: space-between;
                gap: 18px;
                border-bottom: 1px solid var(--line);
                padding-bottom: 14px;
                margin-bottom: 14px;
            }
            .report-title {
                font-size: 1.35rem;
                font-weight: 760;
                margin: 0 0 5px;
            }
            .report-meta {
                color: var(--muted);
                font-size: 0.86rem;
                line-height: 1.55;
            }
            .footer-apex {
                position: fixed;
                left: 0;
                right: 0;
                bottom: 0;
                height: 26px;
                display: flex;
                align-items: center;
                justify-content: center;
                background: #ffffff;
                border-top: 1px solid #e7ecef;
                color: #000000;
                font-size: 0.68rem;
                font-weight: 620;
                z-index: 999;
            }
            .stButton > button, .stDownloadButton > button {
                border-radius: 7px;
                border: 1px solid var(--line-strong);
                font-weight: 700;
                min-height: 42px;
                background: #ffffff !important;
                color: var(--ink) !important;
                box-shadow: none !important;
            }
            .stButton > button[kind="primary"], .stDownloadButton > button[kind="primary"] {
                background: var(--teal) !important;
                border-color: var(--teal) !important;
                color: white !important;
            }
            [data-testid="stFileUploaderDropzone"] {
                border-radius: 8px !important;
                border: 1px dashed var(--line-strong) !important;
                background: #ffffff !important;
                min-height: 136px !important;
                padding: 22px !important;
            }
            [data-testid="stFileUploaderDropzone"] * {
                color: var(--muted) !important;
            }
            [data-testid="stFileUploaderDropzone"] button,
            [data-testid="stBaseButton-secondary"] {
                background: #ffffff !important;
                border: 1px solid var(--line-strong) !important;
                color: var(--ink) !important;
                border-radius: 7px !important;
            }
            [data-testid="stFileUploaderDropzone"] button p,
            [data-testid="stBaseButton-secondary"] p {
                color: var(--ink) !important;
                font-weight: 700 !important;
            }
            [data-testid="stTextInput"] input,
            input[type="text"],
            div[data-baseweb="input"],
            div[data-baseweb="base-input"] {
                background: #ffffff !important;
                border: 1px solid var(--line-strong) !important;
                border-radius: 7px !important;
                color: var(--ink) !important;
                min-height: 42px;
                box-shadow: none !important;
            }
            div[data-baseweb="input"] > div {
                background: #ffffff !important;
            }
            [data-testid="stTextInput"] input::placeholder {
                color: var(--faint) !important;
                opacity: 1 !important;
            }
            [data-testid="stTextInput"] label p {
                font-size: 0.84rem !important;
                font-weight: 650 !important;
                color: var(--ink) !important;
            }
            [data-testid="stCameraInput"] video, [data-testid="stImage"] img {
                border-radius: 8px;
            }
            div[data-baseweb="tab-list"] {
                gap: 8px;
            }
            button[data-baseweb="tab"] {
                border-radius: 7px;
                border: 1px solid var(--line);
                background: #fff;
                height: 38px;
                padding: 0 18px;
            }
            button[data-baseweb="tab"][aria-selected="true"] {
                background: #eaf6f5;
                border-color: #b9dddb;
            }
            [data-testid="stSegmentedControl"] button {
                background: #ffffff !important;
                color: var(--ink) !important;
                border-color: var(--line) !important;
            }
            [data-testid="stSegmentedControl"] button *,
            [data-testid="stSegmentedControl"] label *,
            [data-testid="stSegmentedControl"] [role="radio"] * {
                color: var(--ink) !important;
            }
            [data-testid="stSegmentedControl"] label,
            [data-testid="stSegmentedControl"] [role="radio"] {
                background: #ffffff !important;
                color: var(--ink) !important;
                border-color: var(--line) !important;
            }
            [data-testid="stSegmentedControl"] button[aria-pressed="true"],
            [data-testid="stSegmentedControl"] button[data-selected="true"],
            [data-testid="stSegmentedControl"] label:has(input:checked),
            [data-testid="stSegmentedControl"] [aria-checked="true"] {
                background: #eaf6f5 !important;
                color: var(--teal-2) !important;
                border-color: #b9dddb !important;
            }
            [data-testid="stCheckbox"] label {
                align-items: center;
            }
            [data-testid="stCheckbox"] p {
                font-size: 0.9rem !important;
            }
            @media (max-width: 900px) {
                .block-container { padding: 18px 14px 44px; }
                .topbar { align-items: flex-start; flex-direction: column; }
                .top-actions { width: 100%; justify-content: space-between; text-align: left; }
                h1.page-title, .stMarkdown h1.page-title { font-size: 1.45rem !important; }
                .big-grade { align-items: flex-start; }
                .grade-dial { width: 72px; height: 72px; }
                .report-head { flex-direction: column; }
            }
        </style>
        """,
        unsafe_allow_html=True,
    )


def icon_svg(name):
    icons = {
        "eye": '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"><path d="M2.5 12s3.3-6 9.5-6 9.5 6 9.5 6-3.3 6-9.5 6-9.5-6-9.5-6Z"/><circle cx="12" cy="12" r="3.1"/></svg>',
        "upload": '<svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M12 15V3"/><path d="m7 8 5-5 5 5"/><path d="M5 15v4h14v-4"/></svg>',
        "camera": '<svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><path d="M4 7h3l1.4-2h7.2L17 7h3v12H4Z"/><circle cx="12" cy="13" r="3.7"/></svg>',
    }
    return icons[name]


def topbar():
    st.markdown(
        f"""
        <div class="topbar">
            <div class="brand">
                <div class="brand-mark">{icon_svg("eye")}</div>
                <div>
                    <p class="brand-title">Netra</p>
                    <p class="brand-subtitle">{esc(tr("retinal"))} / {esc(tr("made_for"))}</p>
                </div>
            </div>
            <div class="top-actions">
                <div class="facility"><b>{esc(tr("center"))}</b><br>{esc(tr("operator"))}: Team Apex</div>
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def sidebar():
    st.sidebar.markdown("### Netra")
    st.sidebar.markdown(f'<div class="section-label">{esc(tr("lang"))}</div>', unsafe_allow_html=True)
    lang_left, lang_right = st.sidebar.columns(2)
    with lang_left:
        if st.button("English", use_container_width=True, type="primary" if st.session_state.language == "en" else "secondary"):
            st.session_state.language = "en"
            st.rerun()
    with lang_right:
        if st.button("हिंदी", use_container_width=True, type="primary" if st.session_state.language == "hi" else "secondary"):
            st.session_state.language = "hi"
            st.rerun()

    labels = {
        "analyze": tr("analyze"),
        "report": tr("report"),
        "model_notes": tr("model_notes"),
        "help": tr("help"),
    }
    st.sidebar.write("")
    for key, label in labels.items():
        if st.sidebar.button(label, use_container_width=True, type="primary" if st.session_state.page == key else "secondary", key=f"nav_{key}"):
            st.session_state.page = key
            st.rerun()

    st.sidebar.markdown("---")
    model_ok = MODEL_PATH.exists()
    dot = "status-dot" if model_ok else "status-dot red"
    status = tr("status_loaded") if model_ok else tr("status_missing")
    st.sidebar.markdown(
        f"""
        <div class="section-label">{esc(tr("status"))}</div>
        <p class="body-copy"><span class="{dot}"></span>{esc(status)}</p>
        <p class="body-copy" style="font-size:.8rem;margin-top:8px;">{esc(tr("accuracy_note"))}</p>
        """,
        unsafe_allow_html=True,
    )


@st.cache_resource(show_spinner=False)
def load_interpreter(model_path):
    interpreter = Interpreter(model_path=str(model_path), num_threads=4)
    interpreter.allocate_tensors()
    return interpreter


def get_io_details(interpreter):
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()
    return input_details, output_details


def preprocess_image(pil_image, input_details):
    _, height, width, _ = input_details["shape"]
    image = pil_image.convert("RGB").resize((int(width), int(height)))
    arr = np.asarray(image, dtype=np.float32) / 255.0
    arr = arr * 2.0 - 1.0
    return np.expand_dims(arr, axis=0)


def dequantize(raw, details):
    output = raw.astype(np.float32)
    if details["dtype"] != np.float32:
        scale, zero_point = details["quantization"]
        output = (output - zero_point) * scale
    return output


def normalize_probs(raw, details):
    output = dequantize(raw, details)
    if not np.isclose(output.sum(), 1.0, atol=0.05):
        exp = np.exp(output - np.max(output))
        output = exp / exp.sum()
    return output


def run_inference(interpreter, pil_image):
    input_details, output_details = get_io_details(interpreter)
    interpreter.set_tensor(input_details["index"], preprocess_image(pil_image, input_details))
    interpreter.invoke()

    outputs = {}
    for details in output_details:
        raw = interpreter.get_tensor(details["index"])[0]
        size = raw.shape[0]
        if size == len(DR_CLASSES):
            outputs["dr"] = normalize_probs(raw, details)
        elif size == len(DME_CLASSES):
            outputs["dme"] = normalize_probs(raw, details)
        elif size == len(OCULAR_ORDER):
            outputs["ocular"] = np.clip(dequantize(raw, details), 0.0, 1.0)
    return outputs


def compute_occlusion_heatmap(interpreter, pil_image, target_class, baseline_probs, grid_size=7):
    input_details, output_details = get_io_details(interpreter)
    _, height, width, _ = input_details["shape"]
    resized = np.asarray(pil_image.convert("RGB").resize((int(width), int(height))), dtype=np.float32)
    patch_h = int(height) // grid_size
    patch_w = int(width) // grid_size
    baseline_score = baseline_probs[target_class]
    heat = np.zeros((grid_size, grid_size), dtype=np.float32)

    for row in range(grid_size):
        for col in range(grid_size):
            occluded = resized.copy()
            y0, y1 = row * patch_h, (row + 1) * patch_h
            x0, x1 = col * patch_w, (col + 1) * patch_w
            occluded[y0:y1, x0:x1, :] = 128.0
            occluded_image = Image.fromarray(occluded.astype(np.uint8))
            probs = run_inference(interpreter, occluded_image)["dr"]
            heat[row, col] = max(float(baseline_score - probs[target_class]), 0.0)

    if heat.max() > 0:
        heat /= heat.max()
    heat_full = cv2.resize(heat, (int(width), int(height)), interpolation=cv2.INTER_CUBIC)
    heat_full = cv2.GaussianBlur(np.clip(heat_full, 0, 1), (0, 0), sigmaX=int(width) * 0.03)
    if heat_full.max() > 0:
        heat_full /= heat_full.max()
    return heat_full


def overlay_heatmap(pil_image, heatmap):
    base = np.asarray(pil_image.convert("RGB").resize((heatmap.shape[1], heatmap.shape[0])), dtype=np.uint8)
    color = cv2.applyColorMap((heatmap * 255).astype(np.uint8), cv2.COLORMAP_JET)
    color = cv2.cvtColor(color, cv2.COLOR_BGR2RGB)
    return Image.fromarray(cv2.addWeighted(base, 0.62, color, 0.38, 0))


def result_notes(dr_probs):
    top_two = np.sort(dr_probs)[::-1][:2]
    notes = []
    if top_two[0] < LOW_CONFIDENCE_THRESHOLD:
        notes.append(tr("low_conf"))
    if top_two[0] - top_two[1] < CLOSE_MARGIN_THRESHOLD:
        notes.append(tr("close_margin"))
    if not notes:
        notes.append(tr("good_quality"))
    return notes


def likelihood_label(probability):
    if probability >= 0.70:
        return tr("high")
    if probability >= OCULAR_THRESHOLD:
        return tr("possible")
    return tr("normal")


def recommendation(grade):
    return tr(f"recommend_{grade}")


def image_to_data_url(image):
    if image is None:
        return ""
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def grade_panel(result):
    grade = result["dr_grade"]
    conf = result["dr_confidence"]
    grade_name = DR_CLASSES[grade][st.session_state.language]
    st.markdown(
        f"""
        <div class="panel">
            <div class="section-label">{esc(tr("dr_grade"))}</div>
            <div class="big-grade">
                <div class="grade-dial tone-{grade}">
                    <div>
                        <div class="grade-num">{grade}/4</div>
                        <div class="grade-caption">{esc(pct(conf))}</div>
                    </div>
                </div>
                <div>
                    <p class="headline">{esc(grade_name)}</p>
                    <p class="body-copy">{esc(recommendation(grade))}</p>
                </div>
            </div>
            <div class="severity-scale">
                {''.join(f'<div class="severity-step {"active" if i <= grade else ""}"></div>' for i in range(5))}
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def dme_panel(result):
    dme = result["dme_grade"]
    conf = result["dme_confidence"]
    color_class = "green" if dme == 0 else "amber" if dme == 1 else "red"
    dot_class = "status-dot" if color_class == "green" else "status-dot warn" if color_class == "amber" else "status-dot red"
    st.markdown(
        f"""
        <div class="panel">
            <div class="section-label">{esc(tr("dme"))}</div>
            <div class="metric-row">
                <div>
                    <div class="metric-name"><span class="{dot_class}"></span>{esc(DME_CLASSES[dme][st.session_state.language])}</div>
                    <div class="metric-note">{esc(tr("confidence"))}</div>
                </div>
                <div class="score">{esc(pct(conf))}</div>
            </div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def ocular_table(result):
    rows = []
    for code in OCULAR_REPORT:
        prob = float(result["ocular"][OCULAR_ORDER.index(code)])
        flagged = prob >= OCULAR_THRESHOLD
        rows.append(
            f"""
            <tr>
                <td>{esc(OCULAR_NAMES[code][st.session_state.language])}</td>
                <td>{esc(likelihood_label(prob))}</td>
                <td><span class="badge {'flag' if flagged else ''}">{esc(tr('flagged') if flagged else tr('not_flagged'))}</span></td>
                <td class="score">{esc(pct(prob))}</td>
            </tr>
            """
        )
    st.markdown(
        f"""
        <div class="panel">
            <div class="section-label">{esc(tr("other"))}</div>
            <table class="finding-table">
                <thead>
                    <tr>
                        <th>{esc(tr("finding"))}</th>
                        <th>{esc(tr("likelihood"))}</th>
                        <th>{esc(tr("risk"))}</th>
                        <th>{esc(tr("probability"))}</th>
                    </tr>
                </thead>
                <tbody>{''.join(rows)}</tbody>
            </table>
        </div>
        """,
        unsafe_allow_html=True,
    )


def verification_panel(result):
    notes = "".join(f"<li>{esc(note)}</li>" for note in result["notes"])
    st.markdown(
        f"""
        <div class="muted-panel">
            <div class="section-label">{esc(tr("verification"))}</div>
            <ul class="note-list">{notes}</ul>
            <p class="body-copy" style="font-size:.82rem;margin-top:8px;">{esc(tr("disclaimer"))}</p>
        </div>
        """,
        unsafe_allow_html=True,
    )


def all_probabilities(result):
    st.markdown(f'<div class="section-label">{esc(tr("all_probs"))}</div>', unsafe_allow_html=True)
    for index, probability in enumerate(result["dr_probs"]):
        st.progress(float(probability), text=f"{index} - {DR_CLASSES[index][st.session_state.language]}: {pct(probability)}")
    st.write("")
    for index, probability in enumerate(result["dme_probs"]):
        st.progress(float(probability), text=f"{index} - {DME_CLASSES[index][st.session_state.language]}: {pct(probability)}")


def build_result(image, patient, include_heatmap):
    interpreter = load_interpreter(MODEL_PATH)
    outputs = run_inference(interpreter, image)
    dr_probs = outputs["dr"]
    dme_probs = outputs["dme"]
    dr_grade = int(np.argmax(dr_probs))
    dme_grade = int(np.argmax(dme_probs))
    heatmap_image = None
    if include_heatmap:
        heatmap = compute_occlusion_heatmap(interpreter, image, dr_grade, dr_probs)
        heatmap_image = overlay_heatmap(image, heatmap)

    return {
        "created_at": dt.datetime.now().strftime("%d %b %Y, %I:%M %p"),
        "patient": patient,
        "dr_probs": dr_probs,
        "dme_probs": dme_probs,
        "ocular": outputs["ocular"],
        "dr_grade": dr_grade,
        "dme_grade": dme_grade,
        "dr_confidence": float(dr_probs[dr_grade]),
        "dme_confidence": float(dme_probs[dme_grade]),
        "notes": result_notes(dr_probs),
        "image_data_url": image_to_data_url(image.resize((520, 390))),
        "heatmap_data_url": image_to_data_url(heatmap_image) if heatmap_image else "",
    }


def patient_form():
    st.markdown(f'<div class="section-label">{esc(tr("patient"))}</div>', unsafe_allow_html=True)
    c1, c2 = st.columns(2)
    with c1:
        st.session_state.patient_id = st.text_input(tr("patient_id"), value=st.session_state.patient_id, placeholder=tr("optional"))
        st.session_state.patient_age = st.text_input(tr("age"), value=st.session_state.patient_age, placeholder=tr("optional"))
    with c2:
        st.session_state.patient_name = st.text_input(tr("patient_name"), value=st.session_state.patient_name, placeholder=tr("optional"))
        st.session_state.patient_sex = st.text_input(tr("sex"), value=st.session_state.patient_sex, placeholder=tr("optional"))

    return {
        "id": st.session_state.patient_id.strip(),
        "name": st.session_state.patient_name.strip(),
        "age": st.session_state.patient_age.strip(),
        "sex": st.session_state.patient_sex.strip(),
    }


def analyze_page():
    st.markdown(f'<h1 class="page-title">{esc(tr("analyze_title"))}</h1>', unsafe_allow_html=True)
    st.markdown(f'<p class="page-subtitle">{esc(tr("analyze_subtitle"))}</p>', unsafe_allow_html=True)

    left, right = st.columns([1.05, 1], gap="large")
    with left:
        patient = patient_form()
        st.markdown(f'<div class="section-label" style="margin-top:12px;">{esc(tr("select_image"))}</div>', unsafe_allow_html=True)
        source_left, source_right = st.columns(2)
        with source_left:
            if st.button(tr("upload_tab"), use_container_width=True, type="primary" if st.session_state.image_source == "upload" else "secondary", key="source_upload"):
                st.session_state.image_source = "upload"
                st.session_state.camera_enabled = False
                st.rerun()
        with source_right:
            if st.button(tr("camera_tab"), use_container_width=True, type="primary" if st.session_state.image_source == "camera" else "secondary", key="source_camera"):
                st.session_state.image_source = "camera"
                st.rerun()

        image_file = None
        if st.session_state.image_source == "upload":
            image_file = st.file_uploader(tr("upload_label"), type=["jpg", "jpeg", "png"], label_visibility="collapsed")
        else:
            st.markdown(
                f'<div class="upload-choice">{icon_svg("camera")}<div style="margin-left:14px;text-align:left;"><b>{esc(tr("camera_label"))}</b><br><span class="body-copy">Device camera</span></div></div>',
                unsafe_allow_html=True,
            )
            if not st.session_state.camera_enabled:
                st.markdown(f'<div class="muted-panel"><p class="body-copy">{esc(tr("camera_waiting"))}</p></div>', unsafe_allow_html=True)
                if st.button(tr("enable_camera"), use_container_width=True):
                    st.session_state.camera_enabled = True
                    st.rerun()
            else:
                camera_file = st.camera_input(tr("camera_label"), label_visibility="collapsed")
                if camera_file is not None:
                    image_file = camera_file

        image = None
        if image_file is not None:
            image = Image.open(image_file).convert("RGB")
            st.markdown(f'<div class="section-label" style="margin-top:16px;">{esc(tr("preview"))}</div>', unsafe_allow_html=True)
            st.image(image, use_container_width=True)
            st.markdown(f'<p class="body-copy"><span class="status-dot"></span>{esc(tr("ready"))}</p>', unsafe_allow_html=True)
        else:
            st.markdown(f'<div class="muted-panel"><p class="body-copy">{esc(tr("no_image"))}</p></div>', unsafe_allow_html=True)

        include_heatmap = st.checkbox(tr("heatmap_option"), value=True, help=tr("heatmap_help"))
        run_disabled = image is None or not MODEL_PATH.exists()
        if st.button(tr("run"), type="primary", use_container_width=True, disabled=run_disabled):
            with st.spinner(tr("analysis")):
                st.session_state.latest_result = build_result(image, patient, include_heatmap)
            st.rerun()

    with right:
        st.markdown(f'<div class="section-label">{esc(tr("analysis"))}</div>', unsafe_allow_html=True)
        result = st.session_state.latest_result
        if result is None:
            st.markdown(
                f"""
                <div class="panel empty-summary">
                    <p class="headline" style="margin:0;">{esc(tr("empty_summary"))}</p>
                    <div class="summary-grid">
                        <div class="summary-chip">{esc(tr("dr_grade"))}<br>0-4</div>
                        <div class="summary-chip">{esc(tr("dme"))}<br>0-2</div>
                        <div class="summary-chip">{esc(tr("other"))}<br>6</div>
                    </div>
                    <p class="body-copy">{esc(tr("disclaimer"))}</p>
                </div>
                """,
                unsafe_allow_html=True,
            )
        else:
            st.markdown(f'<p class="body-copy" style="margin-bottom:10px;">{esc(tr("last_updated"))}: {esc(result["created_at"])}</p>', unsafe_allow_html=True)
            grade_panel(result)
            dme_panel(result)
            ocular_table(result)
            verification_panel(result)


def report_text(result):
    patient = result["patient"]
    lines = [
        "Netra Patient Report",
        f"Created: {result['created_at']}",
        f"Patient ID: {patient.get('id') or '-'}",
        f"Name: {patient.get('name') or '-'}",
        f"Age: {patient.get('age') or '-'}",
        f"Sex: {patient.get('sex') or '-'}",
        "",
        f"DR Grade: {result['dr_grade']} - {DR_CLASSES[result['dr_grade']]['en']} ({pct(result['dr_confidence'])})",
        f"DME Risk: {result['dme_grade']} - {DME_CLASSES[result['dme_grade']]['en']} ({pct(result['dme_confidence'])})",
        "",
        "Other findings:",
    ]
    for code in OCULAR_REPORT:
        prob = float(result["ocular"][OCULAR_ORDER.index(code)])
        lines.append(f"- {OCULAR_NAMES[code]['en']}: {pct(prob)}")
    lines += ["", "Verification notes:"] + [f"- {note}" for note in result["notes"]]
    lines += ["", f"Recommendation: {recommendation(result['dr_grade'])}", tr("disclaimer"), "created by team apex"]
    return "\n".join(lines)


def report_page():
    st.markdown(f'<h1 class="page-title">{esc(tr("report_title"))}</h1>', unsafe_allow_html=True)
    result = st.session_state.latest_result
    if result is None:
        st.markdown(f'<div class="panel"><p class="body-copy">{esc(tr("report_empty"))}</p></div>', unsafe_allow_html=True)
        return

    patient = result["patient"]
    st.markdown(
        f"""
        <div class="panel">
            <div class="report-head">
                <div>
                    <p class="report-title">Netra</p>
                    <div class="report-meta">
                        {esc(tr("exam"))}: {esc(result["created_at"])}<br>
                        {esc(tr("patient_id"))}: {esc(patient.get("id") or "-")}<br>
                        {esc(tr("patient_name"))}: {esc(patient.get("name") or "-")}
                    </div>
                </div>
                <div class="report-meta">
                    {esc(tr("age"))}: {esc(patient.get("age") or "-")}<br>
                    {esc(tr("sex"))}: {esc(patient.get("sex") or "-")}<br>
                    {esc(tr("center"))}
                </div>
            </div>
        """,
        unsafe_allow_html=True,
    )
    c1, c2 = st.columns([0.9, 1.1], gap="large")
    with c1:
        if result["image_data_url"]:
            st.markdown(f'<img src="{result["image_data_url"]}" style="width:100%;border-radius:8px;border:1px solid #dce3e6;">', unsafe_allow_html=True)
        if result["heatmap_data_url"]:
            st.markdown(f'<div class="section-label" style="margin-top:14px;">{esc(tr("heatmap"))}</div>', unsafe_allow_html=True)
            st.markdown(f'<img src="{result["heatmap_data_url"]}" style="width:100%;border-radius:8px;border:1px solid #dce3e6;">', unsafe_allow_html=True)
            st.caption(tr("heatmap_caption"))
    with c2:
        grade_panel(result)
        dme_panel(result)
        ocular_table(result)
        verification_panel(result)
        st.download_button(
            tr("download"),
            data=report_text(result),
            file_name="netra_report.txt",
            mime="text/plain",
            use_container_width=True,
            type="primary",
        )
    st.markdown("</div>", unsafe_allow_html=True)


def model_notes_page():
    st.markdown(f'<h1 class="page-title">{esc(tr("model_title"))}</h1>', unsafe_allow_html=True)
    st.markdown(f'<p class="page-subtitle">{esc(tr("model_body"))}</p>', unsafe_allow_html=True)
    c1, c2, c3 = st.columns(3)
    with c1:
        st.markdown(f'<div class="panel"><div class="section-label">DR</div><p class="headline">45.6%</p><p class="body-copy">IDRiD exact grade test accuracy</p></div>', unsafe_allow_html=True)
    with c2:
        st.markdown(f'<div class="panel"><div class="section-label">DME</div><p class="headline">58.3%</p><p class="body-copy">IDRiD exact DME test accuracy</p></div>', unsafe_allow_html=True)
    with c3:
        st.markdown(f'<div class="panel"><div class="section-label">Top-2 DR</div><p class="headline">81.6%</p><p class="body-copy">Correct grade within top two choices</p></div>', unsafe_allow_html=True)

    st.markdown(
        f"""
        <div class="flat-panel">
            <div class="section-label">{esc(tr("verification"))}</div>
            <p class="body-copy">{esc(tr("metric_truth"))}</p>
            <table class="finding-table" style="margin-top:14px;">
                <thead><tr><th>Finding</th><th>Useful signal</th><th>Recall @ 0.5</th></tr></thead>
                <tbody>
                    <tr><td>Cataract</td><td>Good</td><td>71.1%</td></tr>
                    <tr><td>Myopia</td><td>Good</td><td>87.9%</td></tr>
                    <tr><td>Glaucoma</td><td>Moderate</td><td>31.5%</td></tr>
                    <tr><td>AMD</td><td>Weak</td><td>15.0%</td></tr>
                    <tr><td>Hypertension</td><td>Weak</td><td>1.0%</td></tr>
                    <tr><td>Other</td><td>Weak</td><td>8.0%</td></tr>
                </tbody>
            </table>
        </div>
        """,
        unsafe_allow_html=True,
    )


def help_page():
    st.markdown(f'<h1 class="page-title">{esc(tr("help_title"))}</h1>', unsafe_allow_html=True)
    st.markdown(
        f"""
        <div class="panel">
            <ul class="note-list">
                <li>{esc(tr("help_1"))}</li>
                <li>{esc(tr("help_2"))}</li>
                <li>{esc(tr("help_3"))}</li>
            </ul>
        </div>
        <div class="muted-panel" style="margin-top:14px;">
            <p class="body-copy">{esc(tr("disclaimer"))}</p>
        </div>
        """,
        unsafe_allow_html=True,
    )


def main():
    st.set_page_config(page_title="Netra", layout="wide", initial_sidebar_state="expanded")
    set_defaults()
    apply_css()
    sidebar()
    topbar()

    if st.session_state.page == "analyze":
        analyze_page()
    elif st.session_state.page == "report":
        report_page()
    elif st.session_state.page == "model_notes":
        model_notes_page()
    else:
        help_page()

    st.markdown(f'<div class="footer-apex">{esc(tr("footer"))}</div>', unsafe_allow_html=True)


if __name__ == "__main__":
    main()
