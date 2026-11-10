#!/usr/bin/env python3
"""
Automates the App Store Connect v1.0 (Build 16) submission update via the active
Google Chrome tab logged into https://appstoreconnect.apple.com.

Updates:
1. attaches Build 16 (version "16") to App Store Version 1.0 (71c97f5b-50ec-4d1f-9568-081b90e98995)
2. updates es-MX and en-US appInfoLocalizations (Privacy Policy URLs in ES & EN)
3. updates es-MX and en-US appStoreVersionLocalizations (Descriptions, Promotional Text, Keywords,
   Marketing URLs, and Support URLs in ES & EN)
4. updates appStoreReviewDetails with complete v1.0 + StoreKit 2 review instructions
"""

import json
import subprocess
import time

APP_ID = "6826597725"
VERSION_ID = "0f3c4568-fad7-449c-9842-d540b3e703fd"  # 1.0.1
INFO_ID = "f95b5ff2-ace2-40f9-92df-d7325f99f594"
ES_VER_LOC_ID = "0baa6b0c-aff9-4b07-945c-568785869e35"
EN_VER_LOC_ID = "12293c5b-b9ac-47d5-8368-8ccdc575d5f8"
ES_INFO_LOC_ID = "a9b92c0f-07bc-459d-ad85-9700dc50a772"
EN_INFO_LOC_ID = "1a1f3449-3d5f-445e-8776-6929fe6a700b"
IAP_ID = "6826871438"

BUILD_VERSION = "20"

ES_DESCRIPTION = """Overdubly te ayuda a grabar cada parte de una canción en video y unirlas en una sola pantalla. Graba tu voz o tu instrumento una parte a la vez, escucha las anteriores mientras grabas y crea un video listo para compartir.

Graba primero y decide después: elige el diseño, el orden de las partes y el encuadre de cada una cuando ya terminaste de grabar.

LO QUE PUEDES HACER

• Grabar con metrónomo y cuenta regresiva:
Elige el tempo, el compás (4/4, 3/4 o 6/8) y cuántos compases de entrada quieres.

• Ponerle nombre a cada parte:
«Flauta 1», «Voz principal», «Cello»… El nombre aparece dentro de su cuadro en el video.

• Elegir entre 16 diseños:
Acomoda tus partes en filas, columnas, cuadrículas o con una parte destacada.

• Ajustar cada cuadro sin volver a grabar:
Arrastra, acerca y cambia el orden de las partes cuando quieras.

• Ver el resultado antes de crearlo:
Reproduce el video completo, también en pantalla completa.

• Mezclar y sincronizar:
Ajusta el volumen de cada parte, silénciala o escúchala sola, y corrige la sincronización a mano o con Sync Assist.

• Agregar fotos:
Usa una foto de tu galería como una parte más del video.

• Compartir:
Guarda tu video en Fotos o Archivos, o compártelo directamente.

Sin cuentas ni registros.

GRATIS Y PRO
• Gratis: hasta 3 partes, 4 diseños clásicos, videos en 720p y 1080p con la insignia «Made with overdubly.com» y hasta 2 sesiones.
• Overdubly Pro (un solo pago, sin suscripciones): 4 o más partes, los 16 diseños, Sync Assist automático, videos en 4K, sin insignia y sesiones ilimitadas. Incluye Compartir en familia."""

EN_DESCRIPTION = """Overdubly helps you record every part of a song on video and bring them together on one screen. Record your voice or instrument one part at a time, hear the earlier parts while you play, and create a video that's ready to share.

Record first, decide later: pick the layout, the order of the parts, and how each one is framed after you're done recording.

WHAT YOU CAN DO

• Record with a metronome and count-in:
Choose the tempo, time signature (4/4, 3/4, or 6/8), and how many bars of count-in you want.

• Name each part:
"Flute 1", "Lead vocal", "Cello"… The name shows inside its frame in the video.

• Choose from 16 layouts:
Arrange your parts in rows, columns, grids, or with one part in the spotlight.

• Adjust every frame without re-recording:
Drag, zoom, and reorder parts whenever you like.

• See it before you create it:
Play the whole video back, including in full screen.

• Mix and sync:
Set each part's volume, mute or solo it, and fix the timing by hand or with Sync Assist.

• Add photos:
Use a photo from your library as one of the parts.

• Share:
Save your video to Photos or Files, or share it directly.

No accounts or sign-ups.

FREE AND PRO
• Free: up to 3 parts, 4 classic layouts, 720p and 1080p videos with a "Made with overdubly.com" badge, and up to 2 sessions.
• Overdubly Pro (one payment, no subscriptions): 4 or more parts, all 16 layouts, automatic Sync Assist, 4K videos, no badge, and unlimited sessions. Includes Family Sharing."""

ES_WHATS_NEW = """• Overdubly ahora está en español.
• Agrega una foto de tu galería como una parte.
• Silencia o ajusta el volumen de cada parte con controles más claros.
• El metrónomo empieza apagado en las sesiones nuevas.
• Lista para iPhone Duo."""
EN_WHATS_NEW = """• Overdubly now speaks Spanish.
• Add a photo from your library as a part.
• Mute or set the volume of each part with clearer controls.
• The metronome starts off in new sessions.
• Ready for iPhone Duo."""

ES_PROMO = "Graba cada parte de tu canción y únelas en un solo video. Gratis hasta 3 partes; Overdubly Pro con un solo pago, sin suscripciones."
EN_PROMO = "Record every part of your song and bring them together in one video. Free for up to 3 parts; Overdubly Pro is a single payment, no subscriptions."

ES_KEYWORDS = "multipista,acappella,overdub,pantalla dividida,looper,metronomo,musica,video,collage,coro,flauta"
EN_KEYWORDS = "multitrack,acappella,overdub,split screen,video looper,metronome,music studio,collage,harmony,choir"

REVIEW_NOTES = """Overdubly is a multi-track video and audio recording app for musicians. No sign-in or demo account is required.

What's new in 1.0.1 (Build 20): Spanish localization (follows the device language), add a photo from the library as a part (Capture tab > "Add a photo as a part"), labeled Mute/Solo buttons and volume control per part in Mix, the metronome is off by default for new sessions, and the app is built with the iOS 27.2 SDK for iPhone Duo.

How to test:
1. Free features:
   - Capture tab: set tempo and count-in, name the part ("Flute 1"), and record up to 3 parts (allow Camera and Microphone).
   - Mix & Sync tab: adjust volume, Mute/Solo, and timing with the "Manual" panel.
   - Export tab: switch between "Preview" and "Adjust frames", reorder frames, choose one of the 4 classic layouts, and create a 720p or 1080p video.
2. Overdubly Pro (com.seagomezar.loopline.pro.lifetime, non-consumable, one-time purchase):
   - Open it from the "Overdubly Pro" button in the header, or by using any Pro feature (recording a 4th part, choosing a PRO layout, tapping "Find a match", or choosing 4K / Smaller file / removing the badge on Export).
   - The Pro screen shows the one-time price, "Restore Purchases", and links to the Terms of Use (EULA) and Privacy Policy."""

IAP_ES_NAME = "Overdubly Pro"
IAP_ES_DESC = "Desbloquea 4+ partes, 16 diseños, Sync Assist y 4K."
IAP_EN_NAME = "Overdubly Pro"
IAP_EN_DESC = "Unlock 4+ parts, 16 layouts, Sync Assist and 4K."
IAP_REVIEW_NOTE = "One-time non-consumable unlock for Overdubly Pro: 4 or more parts, all 16 layouts, automatic Sync Assist, 4K export, no badge, and unlimited sessions. No subscriptions."


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
        "esWhatsNew": ES_WHATS_NEW,
        "enWhatsNew": EN_WHATS_NEW,
        "buildVersion": BUILD_VERSION,
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

        // 1. Find the release build
        const buildsRes = await req("/iris/v1/builds?filter[app]=" + p.appId + "&limit=30", "GET");
        const builds = buildsRes.data?.data || [];
        const releaseBuild = builds.find(b => b.attributes?.version === p.buildVersion);
        log.push({{step: "findBuild", foundVersion: releaseBuild?.attributes?.version, buildId: releaseBuild?.id, state: releaseBuild?.attributes?.processingState}});

        if (releaseBuild?.id && releaseBuild?.attributes?.processingState === "VALID") {{
            const rAttach = await req("/iris/v1/appStoreVersions/" + p.verId + "/relationships/build", "PATCH", {{
                data: {{ type: "builds", id: releaseBuild.id }}
            }});
            log.push({{step: "attachBuild", status: rAttach.status, err: rAttach.ok ? null : rAttach.raw}});
        }}

        // 2. Update es-MX & en-US appInfoLocalizations (Privacy Policy URLs)
        const rEsInfo = await req("/iris/v1/appInfoLocalizations/" + p.esInfoLocId, "PATCH", {{
            data: {{
                type: "appInfoLocalizations",
                id: p.esInfoLocId,
                attributes: {{
                    name: "Overdubly",
                    subtitle: "Graba cada parte en video",
                    privacyPolicyUrl: "https://overdubly.com/privacy-policy.html?lang=es"
                }}
            }}
        }});
        log.push({{step: "esInfoLoc", status: rEsInfo.status, err: rEsInfo.ok ? null : rEsInfo.raw}});

        const rEnInfo = await req("/iris/v1/appInfoLocalizations/" + p.enInfoLocId, "PATCH", {{
            data: {{
                type: "appInfoLocalizations",
                id: p.enInfoLocId,
                attributes: {{
                    name: "Overdubly",
                    subtitle: "Record every part on video",
                    privacyPolicyUrl: "https://overdubly.com/en/privacy-policy.html"
                }}
            }}
        }});
        log.push({{step: "enInfoLoc", status: rEnInfo.status, err: rEnInfo.ok ? null : rEnInfo.raw}});

        // 3. Update es-MX & en-US appStoreVersionLocalizations
        const rEsVer = await req("/iris/v1/appStoreVersionLocalizations/" + p.esVerLocId, "PATCH", {{
            data: {{
                type: "appStoreVersionLocalizations",
                id: p.esVerLocId,
                attributes: {{
                    description: p.esDesc,
                    whatsNew: p.esWhatsNew,
                    promotionalText: p.esPromo,
                    keywords: p.esKeywords,
                    marketingUrl: "https://overdubly.com/?lang=es",
                    supportUrl: "https://overdubly.com/support.html?lang=es"
                }}
            }}
        }});
        log.push({{step: "esVerLoc", status: rEsVer.status, err: rEsVer.ok ? null : rEsVer.raw}});

        const rEnVer = await req("/iris/v1/appStoreVersionLocalizations/" + p.enVerLocId, "PATCH", {{
            data: {{
                type: "appStoreVersionLocalizations",
                id: p.enVerLocId,
                attributes: {{
                    description: p.enDesc,
                    whatsNew: p.enWhatsNew,
                    promotionalText: p.enPromo,
                    keywords: p.enKeywords,
                    marketingUrl: "https://overdubly.com/en/index.html",
                    supportUrl: "https://overdubly.com/en/support.html"
                }}
            }}
        }});
        log.push({{step: "enVerLoc", status: rEnVer.status, err: rEnVer.ok ? null : rEnVer.raw}});

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
