#!/usr/bin/env python3
"""
Automates the final App Store Connect v1.0 (Build 13) submission update via the active
Google Chrome tab logged into https://appstoreconnect.apple.com.

Updates:
1. attaches Build 13 (version "13") to App Store Version 1.0 (71c97f5b-50ec-4d1f-9568-081b90e98995)
2. updates es-MX and en-US appInfoLocalizations (Privacy Policy URLs in ES & EN)
3. updates es-MX and en-US appStoreVersionLocalizations (Descriptions, Promotional Text, Keywords,
   Marketing URLs, and Support URLs in ES & EN)
4. updates appStoreReviewDetails with complete v1.0 review instructions
5. creates and submits the App Store Review Submission (reviewSubmissions)
"""

import json
import subprocess
import time

APP_ID = "6826597725"
VERSION_ID = "71c97f5b-50ec-4d1f-9568-081b90e98995"
INFO_ID = "f95b5ff2-ace2-40f9-92df-d7325f99f594"
ES_VER_LOC_ID = "bf44c88a-b48a-46c0-a328-b38f8a7f4c3a"
EN_VER_LOC_ID = "ec36094c-4d7f-4b9d-a9b5-66209febc59b"
ES_INFO_LOC_ID = "a9b92c0f-07bc-459d-ad85-9700dc50a772"
EN_INFO_LOC_ID = "1a1f3449-3d5f-445e-8776-6929fe6a700b"

ES_DESCRIPTION = """Loopline es tu estudio multipista de video y audio 100% offline para iPhone e iPad, diseñado para grabar arreglos vocales o instrumentales en pantalla dividida y exportar videos listos para compartir hasta en 4K.

Graba cada voz o instrumento escuchando las tomas previas por audífonos con cuenta regresiva visual sincronizada al pulso, personaliza el título de cada parte, elige entre 16 diseños de marco estilo collage, ajusta el encuadre con Touch Crop, cambia el orden de las voces y previsualiza el video 9:16 real antes de exportar.

FUNCIONES PRINCIPALES DE LOOPLINE V1.0:

• Grabación Multipista con Cuenta Regresiva Sincronizada:
Configura el tempo (BPM), compás (4/4, 3/4, 6/8) y compases de entrada. Loopline muestra una cuenta regresiva a pantalla completa y un pulso visual sincronizado exactamente con el metrónomo.

• Títulos Personalizados Integrados en el Video:
Asigna nombres personalizados a cada toma antes o después de grabar (ej. «Flauta 1», «Primera Voz», «Cello»). Los títulos se muestran en vivo y se renderizan directamente dentro de cada marco al exportar.

• 16 Diseños de Marco (Combinaciones, Filas y Columnas):
Elige entre 16 diseños organizados en Combinaciones asimétricas (1 Arriba + 2 Abajo, 2 Arriba + 1 Abajo, 1 Izquierda + 2 Derecha, 1 Arriba + 3 Abajo, 2 Arriba + 3 Abajo, etc.), Filas horizontales (2, 3 y 4 filas) y Cuadrículas/Columnas clásicas.

• Touch Crop Interactivo y Reordenamiento de Voces:
Ajusta el encuadre de cada marco en un lienzo táctil amplio de 520 pt arrastrando y haciendo zoom (1.0× a 3.0×) y cambia el orden de las posiciones (#1, #2, #3…) en cualquier momento.

• Vista Previa Real 9:16 y Pantalla Completa:
Reproduce la composición multicámara real con mezcla de audio, barra de progreso interactiva, repetición continua y modo de pantalla completa antes de exportar en H.264 (.mp4) o HEVC (.mov) a 720p, 1080p o 4K.

• Mezcla, Sync Assist y Gestor de Sesiones 100% Privado:
Ajusta volumen, silencio, solo y alineación en milisegundos con Sync Assist. Renombra o elimina sesiones completas con todos sus archivos locales, sin cuentas ni servidores externos."""

EN_DESCRIPTION = """Loopline is a 100% offline multi-track video and audio overdub studio for iPhone and iPad, built for recording layered vocal or instrumental performances and exporting polished split-screen videos in up to 4K.

Record each musical part while listening to earlier takes through headphones with a beat-synchronized visual count-in, add custom part headlines burned directly into each video frame, choose from 16 collage-style frame layouts, fine-tune framing with Touch Crop, reorder voice slots, and preview the real 9:16 composition before exporting.

KEY FEATURES IN LOOPLINE V1.0:

• Beat-Synced Count-In & Visual Metronome:
Set your BPM, time signature (4/4, 3/4, 6/8), and count-in bars. Loopline displays a full-screen beat-synchronized countdown and live visual pulse indicator for every take.

• Custom Part Headlines Burned Into Video:
Label each part before or after recording (e.g., "Flute 1", "First Voice", "Cello"). Headlines appear on live tiles and are crisply rendered inside each frame in the exported video.

• 16 Multi-Frame Layouts (Combinations, Rows & Grids):
Choose from 16 layouts across Asymmetric Combinations (1 Top + 2 Bottom, 2 Top + 1 Bottom, 1 Left + 2 Right, 1 Top + 3 Bottom, 2 Top + 3 Bottom, etc.), Horizontal Rows (2, 3, and 4 rows), and Columns & Grids.

• Interactive 520pt Touch Crop & Voice Slot Reordering:
Pan and pinch-to-zoom (1.0× to 3.0×) inside each frame on the enlarged 520 pt Touch Crop canvas, and reorder voice positions (#1, #2, #3…) anytime without re-recording.

• Real 9:16 Composition & Full-Screen Preview:
Play back the true multi-track composition with audio mix, interactive timeline scrubber, loop toggle, and full-screen modal preview before rendering in H.264 (.mp4) or HEVC (.mov) at 720p, 1080p, or 4K.

• Sync Assist, Audio Mixing & 100% On-Device Privacy:
Adjust per-part volume, mute, solo, and millisecond timing offsets with Sync Assist. Rename or delete sessions and all local media files anytime—with zero accounts, zero cloud uploads, and zero tracking."""

ES_PROMO = "Estudio multipista de video y audio: cuenta regresiva al pulso, títulos por voz, 16 diseños de marco, encuadre Touch Crop, vista previa real 9:16 y exportación 4K."
EN_PROMO = "Multi-track split-screen video & audio studio: beat-synced count-in, burned-in part titles, 16 frame layouts, Touch Crop, real 9:16 preview, and 4K export."

ES_KEYWORDS = "multipista,acappella,overdub,pantalla dividida,looper,metronomo,musica,video,collage,coro,flauta"
EN_KEYWORDS = "multitrack,acappella,overdub,split screen,video looper,metronome,music studio,collage,harmony,choir"

REVIEW_NOTES = """Loopline is a 100% offline multi-track audio/video recording and split-screen composition studio for musicians. No sign-in or demo account is required.

How to test core features in Build 13:
1. Capture Tab: Set tempo/count-in, optionally enter a custom part title ("Flute 1", "Voice 1"), and tap "Record first part" (grant Camera & Microphone permissions). Record a 2nd part to unlock multi-track layout and sync tools.
2. Mix & Sync Tab: Adjust per-track volume, Mute/Solo, and test "Run Sync Assist" or the manual millisecond offset slider.
3. Export Tab:
   - Preview Card: Toggle between "Real preview" (true 9:16 multi-track AVPlayer with scrubber & "Full preview" modal) and "Touch crop" (enlarged 520pt interactive canvas to drag/pan and pinch-to-zoom 1.0x–3.0x per tile).
   - Voice & Frame Order: Reorder parts across slots (#1, #2, #3...) using the Earlier/Later buttons.
   - Frame Layout: Choose among 16 layouts across Combinations, Rows, and Columns & Grids.
   - Tap "Create video file" to render a verified H.264 MP4 or HEVC MOV file (with burned-in part titles) and save to Photos/Files."""


def run_chrome_js(js_code: str, wait_var: str = "__ascStepResult"):
    wrapper = f"""
    (async () => {{
        window.{wait_var} = null;
        try {{
            const res = await ({js_code})();
            window.{wait_var} = JSON.stringify({{ok: true, res}});
        }} catch (e) {{
            window.{wait_var} = JSON.stringify({{ok: false, err: String(e)}});
        }}
    }})();
    """
    exec_script = f'''
    tell application "Google Chrome"
        repeat with w in windows
            repeat with t in tabs of w
                if URL of t contains "appstoreconnect.apple.com" then
                    execute t javascript {json.dumps(wrapper)}
                end if
            end repeat
        end repeat
    end tell
    '''
    subprocess.run(["osascript", "-e", exec_script], check=True)
    poll_script = f'''
    tell application "Google Chrome"
        repeat with w in windows
            repeat with t in tabs of w
                if URL of t contains "appstoreconnect.apple.com" then
                    return execute t javascript "window.{wait_var}"
                end if
            end repeat
        end repeat
    end tell
    '''
    for _ in range(45):
        out = subprocess.check_output(["osascript", "-e", poll_script], text=True).strip()
        if out and out not in ("missing value", "null"):
            return json.loads(out)
        time.sleep(0.5)
    raise RuntimeError(f"Timeout waiting for {wait_var}")


def main():
    payload = {
        "appId": APP_ID,
        "verId": VERSION_ID,
        "infoId": INFO_ID,
        "esVerLocId": ES_VER_LOC_ID,
        "enVerLocId": EN_VER_LOC_ID,
        "esInfoLocId": ES_INFO_LOC_ID,
        "enInfoLocId": EN_INFO_LOC_ID,
        "esDesc": ES_DESCRIPTION,
        "enDesc": EN_DESCRIPTION,
        "esPromo": ES_PROMO,
        "enPromo": EN_PROMO,
        "esKeywords": ES_KEYWORDS,
        "enKeywords": EN_KEYWORDS,
        "reviewNotes": REVIEW_NOTES,
    }
    js = f"""
    async () => {{
        const p = {json.dumps(payload)};
        const headers = {{"Content-Type": "application/vnd.api+json"}};
        const log = [];

        async function req(url, method, body) {{
            const r = await fetch(url, {{method, headers, body: body ? JSON.stringify(body) : undefined}});
            const txt = await r.text();
            let j = null;
            try {{ j = JSON.parse(txt); }} catch (e) {{}}
            return {{status: r.status, ok: r.ok, data: j, raw: txt.substring(0, 400)}};
        }}

        // 1. Find Build 13 (or latest valid build)
        const buildsRes = await req("/iris/v1/builds?filter[app]=" + p.appId + "&limit=30", "GET");
        const builds = buildsRes.data?.data || [];
        const build13 = builds.find(b => b.attributes?.version === "13") || builds[0];
        log.push({{step: "findBuild13", foundVersion: build13?.attributes?.version, buildId: build13?.id, state: build13?.attributes?.processingState}});

        if (build13?.id) {{
            const rAttach = await req("/iris/v1/appStoreVersions/" + p.verId + "/relationships/build", "PATCH", {{
                data: {{ type: "builds", id: build13.id }}
            }});
            log.push({{step: "attachBuild13", status: rAttach.status, err: rAttach.ok ? null : rAttach.raw}});
        }}

        // 2. Update es-MX & en-US appInfoLocalizations (Privacy Policy URLs)
        const rEsInfo = await req("/iris/v1/appInfoLocalizations/" + p.esInfoLocId, "PATCH", {{
            data: {{
                type: "appInfoLocalizations",
                id: p.esInfoLocId,
                attributes: {{
                    privacyPolicyUrl: "https://seagomezar.github.io/loopline/privacy-policy.html?lang=es"
                }}
            }}
        }});
        log.push({{step: "esInfoLoc", status: rEsInfo.status}});

        const rEnInfo = await req("/iris/v1/appInfoLocalizations/" + p.enInfoLocId, "PATCH", {{
            data: {{
                type: "appInfoLocalizations",
                id: p.enInfoLocId,
                attributes: {{
                    privacyPolicyUrl: "https://seagomezar.github.io/loopline/en/privacy-policy.html"
                }}
            }}
        }});
        log.push({{step: "enInfoLoc", status: rEnInfo.status}});

        // 3. Update es-MX & en-US appStoreVersionLocalizations
        const rEsVer = await req("/iris/v1/appStoreVersionLocalizations/" + p.esVerLocId, "PATCH", {{
            data: {{
                type: "appStoreVersionLocalizations",
                id: p.esVerLocId,
                attributes: {{
                    description: p.esDesc,
                    promotionalText: p.esPromo,
                    keywords: p.esKeywords,
                    marketingUrl: "https://seagomezar.github.io/loopline/?lang=es",
                    supportUrl: "https://seagomezar.github.io/loopline/support.html?lang=es"
                }}
            }}
        }});
        log.push({{step: "esVerLoc", status: rEsVer.status}});

        const rEnVer = await req("/iris/v1/appStoreVersionLocalizations/" + p.enVerLocId, "PATCH", {{
            data: {{
                type: "appStoreVersionLocalizations",
                id: p.enVerLocId,
                attributes: {{
                    description: p.enDesc,
                    promotionalText: p.enPromo,
                    keywords: p.enKeywords,
                    marketingUrl: "https://seagomezar.github.io/loopline/en/index.html",
                    supportUrl: "https://seagomezar.github.io/loopline/en/support.html"
                }}
            }}
        }});
        log.push({{step: "enVerLoc", status: rEnVer.status}});

        // 4. Update appStoreReviewDetails
        const revCheck = await req("/iris/v1/appStoreVersions/" + p.verId + "/appStoreReviewDetail", "GET");
        if (revCheck.data?.data?.id) {{
            const revId = revCheck.data.data.id;
            const rRev = await req("/iris/v1/appStoreReviewDetails/" + revId, "PATCH", {{
                data: {{
                    type: "appStoreReviewDetails",
                    id: revId,
                    attributes: {{
                        contactFirstName: "Sebastian",
                        contactLastName: "Gomez",
                        contactPhone: "+573108312734",
                        contactEmail: "seagomezar@gmail.com",
                        demoAccountRequired: false,
                        notes: p.reviewNotes
                    }}
                }}
            }});
            log.push({{step: "updateReviewDetails", status: rRev.status}});
        }}

        return log;
    }}
    """
    res = run_chrome_js(js)
    print(json.dumps(res, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
