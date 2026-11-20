# Task Track — macOS MVP

Base nativa SwiftUI + AppKit para seguimiento de tiempo.

## Incluido

- Timer iniciar/parar con descripción y selector de proyecto.
- Historial de sesiones y datos simulados.
- Status item de la barra de menús con popover.
- Identificador estable de sesión y propietario independiente de Created By.
- Lista y calendario personales, modo manual con ⌘D y editor de sesiones.
- Registro opcional de aplicaciones en primer plano y revisión de sugerencias.
- Persistencia local del temporizador y las sesiones.
- Adaptador `TimeTrackingSyncClient` preparado para Notion.

## Ejecutar en macOS

```bash
cd macos/ToggleTask
swift run
```

Este entorno Windows no puede compilar AppKit; la validación final debe hacerse en Xcode/macOS.

## GitHub Actions

El workflow `.github/workflows/macos.yml` compila el paquete en `macos-latest` para cada push a `main`/`master` y cada pull request. El resultado se consulta en la pestaña **Actions** del repositorio.
