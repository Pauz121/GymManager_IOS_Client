# GymManager Client iOS

Applicazione nativa SwiftUI dedicata ai Clienti GymManager. È separata dall'app Trainer/Super Admin, che rimane in `IOS/`.

## Apertura

Da macOS, aprire `IOS_Client/GymManagerClient.xcworkspace` oppure `IOS_Client/GymManagerClient.xcodeproj` con Xcode 16.4 o successivo.

Il workspace contiene esclusivamente il progetto Client. Il target Trainer non viene incluso né modificato.

## Configurazione

Il repository è autosufficiente e non richiede la cartella Trainer. Per usare il backend live, copiare `IOS_Client/Config/Local.xcconfig.example` in `IOS_Client/Config/Local.xcconfig` e sostituire esclusivamente i placeholder con URL Supabase e publishable key client-safe dell'ambiente autorizzato. `Local.xcconfig` è ignorato da Git.

Senza configurazione live il progetto può essere compilato; l'app segnala la configurazione mancante e, in Debug, permette di raggiungere l'onboarding e la demo locale.

Non inserire service role, secret key, password, token o credenziali provider nei file Xcode o nel codice Swift.

## Validazione

Su Windows è disponibile la validazione strutturale read-only:

```powershell
pwsh -File IOS_Client/scripts/validate-client-ios.ps1
```

Build, XCTest e verifica su simulatore/dispositivo richiedono macOS e Xcode.
