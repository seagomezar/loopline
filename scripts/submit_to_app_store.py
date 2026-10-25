#!/usr/bin/env python3
"""
Automates the final App Store Connect v1.0 (Build 15) submission update via the active
Google Chrome tab logged into https://appstoreconnect.apple.com.

Updates:
1. attaches Build 15 (version "15") to App Store Version 1.0 (71c97f5b-50ec-4d1f-9568-081b90e98995)
2. updates es-MX and en-US appInfoLocalizations (Privacy Policy URLs in ES & EN)
3. updates es-MX and en-US appStoreVersionLocalizations (Descriptions, Promotional Text, Keywords,
   Marketing URLs, and Support URLs in ES & EN)
4. updates appStoreReviewDetails with complete v1.0 + StoreKit 2 review instructions
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
IAP_ID = "6826871438"

ES_DESCRIPTION = """Loopline es tu estudio multipista de video y audio 100% offline para iPhone e iPad, diseñado para grabar arreglos vocales o instrumentales en pantalla dividida y exportar videos listos para compartir hasta en 4K.

A diferencia de otras apps que te obligan a elegir el marco antes de grabar o cobran suscripciones semanales, en Loopline grabas primero con total libertad y eliges o cambias entre los 16 diseños de marco, el encuadre Touch Crop (1.0× a 3.0×) y el orden de las voces después de grabar.

FUNCIONES PRINCIPALES DE LOOPLINE V1.0:

• Grabación Multipista con Cuenta Regresiva Sincronizada:
Configura BPM, compás (4/4, 3/4, 6/8) y compases de entrada con pulso visual en vivo.

• Títulos Personalizados Integrados en el Video:
Nombra cada toma («Flauta 1», «Primera Voz», «Cello») y expórtalos renderizados dentro de cada marco.

• 16 Diseños de Marco (Combinaciones, Filas y Columnas):
Incluye 4 diseños simétricos clásicos gratis y 12 combinaciones asimétricas Pro (Frames 40/60, Diptic 60/40, Center Stage, Hero).

• Touch Crop Interactivo (520 pt) y Reordenamiento de Voces:
Arrastra y haz zoom (1.0× a 3.0×) en cada marco y reordena las posiciones (#1, #2, #3…) sin volver a grabar.

• Vista Previa Real 9:16 y Pantalla Completa:
Reproduce la composición real con barra de tiempo y modo pantalla completa antes de exportar en H.264 (.mp4) o HEVC (.mov) a 720p, 1080p o 4K.

• Mezcla, Sync Assist y Privacidad 100% Local:
Ajusta volumen, paneo estéreo, Mute/Solo y alineación en milisegundos sin cuentas ni servidores externos.

LOOPLINE GRATIS VS. LOOPLINE PRO (PAGO ÚNICO DE POR VIDA):
• Loopline Gratis ($0 para siempre): Hasta 3 voces, metrónomo completo, Touch Crop, mezclador manual ±250 ms, 4 diseños simétricos clásicos, exportación 720p/1080p H.264 (.mp4) con insignia discreta y hasta 2 sesiones locales.
• Loopline Pro (Desbloqueo único de por vida — Sin suscripciones): De 4 a 6+ voces, los 16 diseños completos, Sync Assist automático en 1 toque, exportación 4K UHD y HEVC (.mov), sin marca de agua y sesiones locales ilimitadas. Incluye Compartir en Familia."""

EN_DESCRIPTION = """Loopline is a 100% offline multi-track video and audio overdub studio for iPhone and iPad, built for recording layered vocal or instrumental performances and exporting polished split-screen videos in up to 4K.

Unlike split-screen apps that lock your grid before you play a single note or charge recurring weekly subscriptions, Loopline lets you record first and freely switch across 16 frame layouts, pan/zoom each performer with Touch Crop (1.0× to 3.0×), and reorder voice slots after recording.

KEY FEATURES IN LOOPLINE V1.0:

• Beat-Synced Count-In & Visual Metronome:
Set BPM, time signature (4/4, 3/4, 6/8), and count-in bars with a full-screen countdown and live beat pulse.

• Custom Part Headlines Burned Into Video:
Label each part ("Flute 1", "First Voice", "Cello") and render titles directly inside each video frame.

• 16 Multi-Frame Layouts (Combinations, Rows & Grids):
4 classic symmetric layouts included free, plus 12 Pro asymmetric and spotlight layouts (Frames 40/60, Diptic 60/40, Center Stage, Hero).

• Interactive 520pt Touch Crop & Voice Slot Reordering:
Pan and pinch-to-zoom (1.0× to 3.0×) per tile and reorder voice slots (#1, #2, #3…) anytime.

• Real 9:16 Composition & Full-Screen Preview:
Play back the true multi-track composition with interactive scrubber and full-screen modal before exporting in H.264 (.mp4) or HEVC (.mov) at 720p, 1080p, or 4K.

• Sync Assist, Audio Mixing & 100% On-Device Privacy:
Per-part volume, stereo pan, mute, solo, millisecond timing offsets, and local session management with zero cloud uploads or tracking.

LOOPLINE FREE VS. LOOPLINE PRO (ONE-TIME LIFETIME UNLOCK):
• Loopline Free ($0 Forever): Up to 3 voices, beat-synced count-in, Touch Crop, manual ±250ms sync slider, 4 classic symmetric layouts, 720p & 1080p H.264 (.mp4) export with a subtle corner badge, and up to 2 local sessions.
• Loopline Pro (One-Time Lifetime Purchase — No Subscriptions): 4 to 6+ voices, all 16 layouts, 1-tap Auto Sync Assist, 4K UHD & HEVC (.mov) export, no watermark, and unlimited local sessions. Supports Apple Family Sharing."""

ES_PROMO = "Estudio multipista de video y audio offline: cuenta regresiva al pulso, 16 diseños, Touch Crop, Sync Assist y 4K. Gratis hasta 3 voces; Pro en pago único."
EN_PROMO = "Offline multi-track split-screen video & audio studio: beat-synced count-in, 16 layouts, Touch Crop, Auto Sync Assist & 4K. Free up to 3 voices; 1-time Pro."

ES_KEYWORDS = "multipista,acappella,overdub,pantalla dividida,looper,metronomo,musica,video,collage,coro,flauta"
EN_KEYWORDS = "multitrack,acappella,overdub,split screen,video looper,metronome,music studio,collage,harmony,choir"

REVIEW_NOTES = """Loopline is a 100% offline multi-track audio/video recording and split-screen composition studio for musicians. No sign-in or demo account is required.

How to test core features & StoreKit 2 In-App Purchase in Build 15:
1. Free Tier (Immediate Access):
   - Capture Tab: Set tempo/count-in, enter a custom part title ("Flute 1", "Voice 1"), and record up to 3 parts (grant Camera & Microphone permissions).
   - Mix & Sync Tab: Adjust per-track volume, stereo pan, Mute/Solo, and the manual ±250 ms offset slider.
   - Export Tab: Preview in 9:16 ("Real preview" or 520pt "Touch crop"), reorder voice slots (#1, #2, #3), choose any of the 4 classic layouts, and export in 720p or 1080p H.264 (.mp4).
2. Loopline Pro — Lifetime Unlock (`com.seagomezar.loopline.pro.lifetime`, Non-Consumable StoreKit 2 IAP):
   - Tap the "Loopline Pro" pill in the top header, or select any Pro feature (recording a 4th+ voice, choosing one of the 12 PRO asymmetric layouts, tapping "Find a match" Auto Sync Assist, or selecting 4K / HEVC / Remove watermark on Export) to open the Loopline Pro sheet.
   - The paywall clearly displays the one-time price, "Restore Purchases" button, and direct links to Terms of Use (EULA) and Privacy Policy."""


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
                    execute t javascript {json.dumps(wrapper, ensure_ascii=False)}
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
        const p = {json.dumps(payload, ensure_ascii=False)};
        const headers = {{"Content-Type": "application/vnd.api+json"}};
        const log = [];

        async function req(url, method, body) {{
            const r = await fetch(url, {{method, headers, body: body ? JSON.stringify(body) : undefined}});
            const txt = await r.text();
            let j = null;
            try {{ j = JSON.parse(txt); }} catch (e) {{}}
            return {{status: r.status, ok: r.ok, data: j, raw: txt.substring(0, 400)}};
        }}

        // 1. Find Build 15 (or latest valid build)
        const buildsRes = await req("/iris/v1/builds?filter[app]=" + p.appId + "&limit=30", "GET");
        const builds = buildsRes.data?.data || [];
        const build15 = builds.find(b => b.attributes?.version === "15") || builds[0];
        log.push({{step: "findBuild15", foundVersion: build15?.attributes?.version, buildId: build15?.id, state: build15?.attributes?.processingState}});

        if (build15?.id && build15?.attributes?.processingState === "VALID") {{
            const rAttach = await req("/iris/v1/appStoreVersions/" + p.verId + "/relationships/build", "PATCH", {{
                data: {{ type: "builds", id: build15.id }}
            }});
            log.push({{step: "attachBuild15", status: rAttach.status, err: rAttach.ok ? null : rAttach.raw}});
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
