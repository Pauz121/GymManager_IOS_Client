# GymManager Client iOS

Applicazione nativa SwiftUI dedicata ai Clienti GymManager. È separata dall'app Trainer/Super Admin, che rimane in `IOS/`.

## Apertura

Da macOS, aprire `IOS_Client/GymManagerClient.xcworkspace` oppure `IOS_Client/GymManagerClient.xcodeproj` con Xcode 16.4 o successivo.

Il workspace contiene esclusivamente il progetto Client. Il target Trainer non viene incluso né modificato.

## Configurazione

Il repository è autosufficiente e non richiede la cartella Trainer. `Config/Backend.xcconfig` contiene esclusivamente URL e publishable key client-safe del backend production, valori che vengono comunque incorporati nel bundle iOS e la cui sicurezza dipende da Auth e RLS, non dalla segretezza della chiave. Per usare un ambiente diverso, copiare `IOS_Client/Config/Local.xcconfig.example` in `IOS_Client/Config/Local.xcconfig`: l'override locale è ignorato da Git e non deve contenere service role o altri segreti.

Senza configurazione live il progetto può essere compilato; l'app segnala la configurazione mancante e, in Debug, permette di raggiungere l'onboarding e la demo locale.

Non inserire service role, secret key, password, token o credenziali provider nei file Xcode o nel codice Swift.

## Validazione

Su Windows è disponibile la validazione strutturale read-only:

```powershell
pwsh -File IOS_Client/scripts/validate-client-ios.ps1
```

Build, XCTest e verifica su simulatore/dispositivo richiedono macOS e Xcode.
