# Toggle Task — macOS MVP

Base nativa SwiftUI + AppKit para seguimiento de tiempo.

## Incluido

- Timer iniciar/parar con descripción y selector de proyecto.
- Historial de sesiones y datos simulados.
- Status item de la barra de menús con popover.
- Deduplicación local por proyecto, inicio y usuario.
- Adaptador `TimeTrackingSyncClient` preparado para Notion.

## Ejecutar en macOS

```bash
cd macos/ToggleTask
swift run
```

Este entorno Windows no puede compilar AppKit; la validación final debe hacerse en Xcode/macOS.

## GitHub Actions

El workflow `.github/workflows/macos.yml` compila el paquete en `macos-latest` para cada push a `main`/`master` y cada pull request. El resultado se consulta en la pestaña **Actions** del repositorio.
