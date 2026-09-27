# MediVorrat 1.0 – Einrichtung

    cd ~/github
    unzip -o ~/Downloads/MediVorrat.zip
    cd MediVorrat
    TEAM=$(grep -m1 DEVELOPMENT_TEAM ~/github/blaseunddarm-apps/ios/project.yml | sed 's/.*: *//; s/"//g')
    sed -i '' "s/TEAMID/${TEAM}/" project.yml && grep DEVELOPMENT_TEAM project.yml
    xcodegen generate && open MediVorrat.xcodeproj
    git init && git add . && git commit -m "MediVorrat 1.0: Grundgerüst"

Ist DEVELOPMENT_TEAM danach leer, das Team einmal in Xcode unter Signing & Capabilities wählen.
Die HealthKit-Capability wird über das Entitlement automatisch registriert.

Test auf dem iPhone (nicht Simulator): Die Health-Medikamente gibt es nur auf dem echten Gerät.
