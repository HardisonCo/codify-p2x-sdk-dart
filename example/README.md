# codify_p2x_sdk example

Minimal demonstration of the SDK. Constructs a `P2xClient`, fires a request, displays the result.

## Run

```bash
cd example
flutter pub get
flutter run
```

Override the API base URL at run time:

```bash
flutter run --dart-define=P2X_BASE_URL=https://api.project20x.com/api
```

## See also

- `../README.md` — full SDK documentation
- `../CLAUDE.md` — architecture
- `../test/client/p2x_client_test.dart` — base-client contract tests
