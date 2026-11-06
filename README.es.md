---
description: "Notificaciones nativas de macOS, aprobaciones, formularios de preguntas y panel de sesiones para DSH Desktop."
kind: "package-reference"
---

# DSH Notify

[简体中文](README.md) · [English](README.en.md) · [日本語](README.ja.md) · **Español** · [Français](README.fr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md) · [Português](README.pt.md)

Añade notificaciones nativas de macOS, aprobaciones, formularios de preguntas y un panel de sesiones en la barra de menús a **DeepSeek Harness Desktop**. Responde desde una notificación o vuelve al espacio de trabajo y a la sesión correspondientes.

El proyecto combina un complemento de DSH y el asistente **DSH Notify.app**, que se inicia y se cierra con Desktop. No requiere navegador, DSH Bridge ni servicios de modelos adicionales. Es un complemento de la comunidad; la versión estable actual es **v0.5.0**. Consulta las [versiones y descargas](https://github.com/realDGD/dsh-macos-notify/releases/tag/v0.5.0).

## Funciones

| Función | Comportamiento |
| --- | --- |
| Notificaciones nativas | Informa de finalización, errores, aprobaciones y preguntas. Un clic abre la sesión correspondiente. |
| Aprobación rápida | Elige **permitir una vez** o **Rechazar** desde la notificación o el menú; abre los detalles para revisar el comando. |
| Formularios completos | Un aviso abre todas las preguntas, con selección única o múltiple, campos de texto independientes y un solo envío del conjunto. |
| Panel de sesiones | Muestra actividad, subagentes anidados y las cinco sesiones principales recientes, con estado y progreso. |
| Contexto y código | Representa tablas Markdown, fórmulas y código localmente, con resaltado Shell/JSON y ajuste de líneas en comandos y argumentos. |
| Idiomas | Sigue el idioma de DSH: chino simplificado, inglés, japonés, español, francés, alemán, ruso y portugués. Los nombres, preguntas, opciones, respuestas y comandos conservan su idioma original. |

Los seis idiomas añadidos están disponibles en el código fuente actual y todavía no se han publicado en una versión estable. Para usarlos, recompila el asistente nativo de la misma revisión. Consulta las [fuentes terminológicas y el mantenimiento](docs/localization.md).

DSH determina si una solicitud sigue siendo válida. La primera respuesta aceptada prevalece; las solicitudes respondidas, canceladas o caducadas se retiran y los botones antiguos no repiten acciones. Cerrar una ventana de preguntas o desconectarse brevemente conserva los borradores. **Borrar respuestas** limpia las opciones y el texto sin cancelar la solicitud. Los borradores solo viven en la memoria del asistente; se eliminan cuando DSH confirma la respuesta, cancelación o retirada. Salir del asistente descarta los borradores sin enviar. Un resultado sin confirmar nunca se reintenta automáticamente.

## Imágenes de la interfaz

**Estas imágenes y grabaciones muestran la interfaz en inglés como ejemplo. El complemento también ofrece la interfaz en español.** Son capturas nativas reales con espacios de trabajo, sesiones y solicitudes ficticios. Los controles del Centro de Notificaciones siguen el idioma de macOS. Haz clic para ampliar. Consulta el [origen y alcance de las imágenes](docs/images/README.md).

### Sesiones y acciones rápidas

<table>
<tr><th>Menú de sesiones</th><th>Estados y animación del icono</th></tr>
<tr>
<td valign="top"><a href="docs/images/menu-sessions-en.png"><img src="docs/images/menu-sessions-en.png" alt="Ejemplo en inglés del panel con sesiones activas, recientes, aprobaciones y preguntas" width="400"></a></td>
<td valign="top"><a href="docs/images/menu-icon-states-en.gif"><img src="docs/images/menu-icon-states-en.gif" alt="Ejemplo en inglés de los estados y la rotación del pez" width="400"></a></td>
</tr>
</table>

El pez gira mientras se ejecutan tareas. Naranja indica aprobaciones o preguntas; rojo, una interrupción anormal; verde, finalización. La prioridad es **entrada necesaria > interrupción anormal > finalización**. Abrir el panel restaura el icono blanco. Una detención iniciada por el usuario no genera una alerta de error.

### Aprobaciones y detalles

<table>
<tr><th>Notificación y acciones</th><th>Revisión del comando y los permisos</th></tr>
<tr>
<td valign="top"><a href="docs/images/notification-approval-en.png"><img src="docs/images/notification-approval-en.png" alt="Notificación de aprobación en inglés con acciones de permitir, rechazar y ver detalles" width="400"></a></td>
<td valign="top"><a href="docs/images/approval-details-en.png"><img src="docs/images/approval-details-en.png" alt="Ventana de detalles en inglés con comando, argumentos completos y contexto" width="400"></a></td>
</tr>
</table>

**Ver detalles** abre el motivo, comando, argumentos completos y contexto. Los argumentos tienen sangría y las líneas largas se ajustan. **Ver original** y **Copiar argumentos originales** conservan el contenido original. El formato de visualización no cambia la solicitud enviada a DSH.

### Preguntas y formularios

<table>
<tr><th>Notificación de preguntas</th><th>Opciones y texto por pregunta</th></tr>
<tr>
<td valign="top"><a href="docs/images/notification-questionnaire-en.png"><img src="docs/images/notification-questionnaire-en.png" alt="Ejemplo en inglés de una notificación con dos preguntas" width="400"></a></td>
<td valign="top"><a href="docs/images/questionnaire-en.png"><img src="docs/images/questionnaire-en.png" alt="Formulario en inglés con selección única y múltiple, texto independiente y envío conjunto" width="400"></a></td>
</tr>
</table>

**Abrir preguntas** abre el formulario completo; **Enviar todas las respuestas** lo envía de una vez. Si respondes primero en DSH, la solicitud de la notificación antigua queda invalidada. **Abrir en DSH** cierra la ventana cuando se confirma la selección de la sesión. Las demostraciones no ejecutan comandos, llaman a modelos ni envían respuestas reales.

<a id="installation"></a>

## Instalación

**Se recomienda instalar desde el administrador de complementos de DSH Desktop.** Necesitas macOS 13 o posterior, DSH Desktop oficial y Apple Command Line Tools. La compatibilidad de ejecución y el estado del asistente se han comprobado en `0.2.2-rc.1`. Desktop utiliza su Node.js/pnpm incluido; Node.js 22+ por separado solo es necesario para compilaciones manuales o desarrollo. Consulta los límites de versiones antiguas de macOS, Intel y clics reales en [compatibilidad](docs/compatibility.md).

`v0.5.0` instala el asistente automáticamente; `v0.5.0-preview.1` requiere el procedimiento manual. Para los nuevos idiomas, ten en cuenta la nota sobre el código fuente anterior.

1. Ejecuta esto en Terminal y completa la instalación del sistema. Si las herramientas ya están instaladas, continúa. No necesitas Xcode completo ni un certificado de pago.

   ```sh
   xcode-select --install
   ```

2. Abre **Complementos → Agregar complemento** en Desktop. Pega esta dirección, comprueba que confías en el origen y elige **Instalar**:

   ```text
   github:realDGD/dsh-macos-notify
   ```

3. Si se bloquean los scripts, revisa el complemento y autoriza su ejecución y el reintento. Se compila `/Applications/DSH Notify.app`. Una compilación coincidente se reutiliza; las actualizaciones conservan ajustes y una copia de la aplicación anterior.
4. Elige **Habilitar ahora**. Guarda el trabajo, sal de Desktop con **⌘Q** y ábrelo de nuevo; cerrar una ventana no cierra la aplicación. Acepta el permiso de notificaciones de **DSH Notify** cuando macOS lo solicite.
5. En **Configuración → DSH Notify**, comprueba la conexión y los permisos. Envía una notificación de prueba y haz clic en ella para verificar la sesión. La aceptación por macOS solo acredita la entrega aceptada; el clic verifica la navegación.

Consulta la [guía oficial de complementos](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/client/ui-plugin-manager/README.md).

### Usar Terminal

Instala el comando mediante **Manage dsh Command…** en el menú de Desktop, abre un terminal nuevo y ejecuta:

```sh
dsh plugin --profile desktop add github:realDGD/dsh-macos-notify
```

Desktop usa el perfil `desktop`; `--profile web` pertenece a otro entorno Web. Autoriza los scripts desde el administrador si hace falta. Consulta la [instalación detallada](docs/install.md) y la [guía oficial del comando](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/desktop/README.md#terminal-command).

### Pedir ayuda a DSH

Copia esto en una conversación nueva:

```text
Instala DSH Notify en DeepSeek Harness Desktop oficial en este Mac:
https://github.com/realDGD/dsh-macos-notify
Lee primero README y docs/install.md. Comprueba la versión de DSH, macOS 13+ y Command Line Tools.
Usa el perfil desktop y el administrador de complementos o el comando dsh incluido.
Comprueba si la versión incluye el idioma necesario y compila /Applications/DSH Notify.app desde la misma revisión del complemento.
Conserva los ajustes y las copias anteriores. Indícame qué debo hacer en los diálogos de instalación del sistema, aprobación de scripts y permiso de notificaciones.
Pídeme que guarde el trabajo, salga y vuelva a abrir Desktop. Guíame para enviar y pulsar la notificación de prueba y verificar la sesión correcta.
```

### Instalación manual

Para versiones preliminares antiguas, fallos de la instalación automática o desarrollo: instala Command Line Tools y [Node.js 22+](https://nodejs.org/en/download), y ejecuta:

```sh
git clone https://github.com/realDGD/dsh-macos-notify.git
cd dsh-macos-notify
npm ci --ignore-scripts
bash macos/install.sh
pwd
```

Pega la ruta absoluta de `pwd` en **Complementos → Agregar complemento**; habilita, reinicia y prueba. También puedes descargar un archivo de código fuente completo de [Releases](https://github.com/realDGD/dsh-macos-notify/releases), extraerlo y empezar por `npm ci --ignore-scripts`. Mantén complemento y asistente en la misma revisión. El icono oficial se obtiene de `/Applications/DeepSeek Harness.app`; otras ubicaciones se configuran según la [guía](docs/install.md).

### Problemas habituales

| Problema | Solución |
| --- | --- |
| Falta `swiftc` | Completa la instalación de `xcode-select --install` y reintenta. |
| Scripts bloqueados | Autoriza los scripts y reintenta desde DSH. |
| No existe `dsh` | Usa el administrador o repara el comando desde Desktop y abre un terminal nuevo. |
| Versión incompatible | Elige versiones coincidentes según la [guía](docs/compatibility.md). |
| Falta el asistente o se rechaza la actualización | Usa el procedimiento manual o resuelve los borradores y cierra las ventanas de aprobación y preguntas. |
| GitHub inaccesible | Comprueba la conexión o usa un archivo completo ya descargado. Cambiar el registro npm no descarga GitHub. |
| No llegan notificaciones | Revisa **Ajustes del Sistema → Notificaciones → DSH Notify** y los modos de concentración; envía una prueba. |

El asistente se inicia y se detiene con Desktop; no es un ítem de inicio de sesión.

## Uso diario

- Haz clic en el pez. La actividad prioriza sesiones fijadas, solicitudes de entrada e interrupciones anormales, seguidas de sesiones en ejecución. Las recientes muestran hasta cinco sesiones principales, sin duplicados ni subagentes.
- Los cupos de cada sección cuentan solo sesiones principales. Al expandir una se muestran dos subagentes; la fila de más subagentes revela el resto. La altura crece con el contenido y, al alcanzar el límite, se usan flechas arriba/abajo. No hay rueda ni barra de desplazamiento. Una vista de una sola fila no fija la sesión principal.
- Arriba/Abajo seleccionan la fila de más subagentes; Enter/Espacio la expanden o contraen y Derecha también expande. El foco pasa al primer subagente nuevo. Izquierda en esa fila vuelve a la sesión principal.
- El número de tareas aparece en el anillo de progreso; un plan completado se convierte en una marca verde. Sin plan no hay anillo. Las aprobaciones tienen botones verticales; las preguntas abren el formulario. **Acciones** separa varias solicitudes de la misma sesión.
- Configura tipos, sonido, resultados independientes de subagentes, espera a su finalización y silencio al visualizar la sesión.
- El clic derecho ofrece abrir DSH, configuración de DSH Notify, ocultar la barra y salir de DSH. El engranaje abre la configuración. Un clic fuera cierra el panel y conserva las ventanas independientes.
- Salir requiere confirmación si hay tareas en ejecución, aprobaciones, respuestas pendientes o información antigua, incompleta o no disponible. El asistente solicita una salida normal de la aplicación.
- Ocultar la barra mantiene las notificaciones y ventanas nativas. Vuelve a activarla en la configuración de DSH Notify.
- Cambia el idioma en DSH. Las ventanas abiertas actualizan sus textos y conservan opciones y borradores; las notificaciones entregadas mantienen el idioma de envío.

El contexto se representa localmente con Markdown y KaTeX: títulos, listas, citas, tablas, fórmulas y código. Las imágenes remotas no se cargan automáticamente y el HTML no se ejecuta. El contenido largo indica su límite; abre DSH para leerlo completo.

## Actualización y desinstalación

Guarda el trabajo, resuelve los borradores y cierra las ventanas nativas antes de actualizar. En el administrador actual, **elimina el complemento y agrégalo de nuevo**. Las versiones con instalación automática comprueban y actualizan el asistente. En una instalación manual ejecuta `npm ci --ignore-scripts` y `bash macos/install.sh`, y vuelve a añadir el mismo directorio. Reinicia Desktop normalmente. Se conservan ajustes y copias; se confirma que el proceso anterior terminó antes de sustituir la aplicación.

Si migras desde `dsh-notify-web` / `DSH Jump.app`, elimina el complemento antiguo y la retransmisión de finalización/error para evitar duplicados. Se conserva la identidad histórica del asistente para permisos y compatibilidad.

Para desinstalar, elimina el complemento en DSH y ejecuta desde el código fuente:

```sh
bash macos/uninstall.sh
```

Reinicia Desktop. Se mantienen los ajustes y las copias de aplicaciones; solo se eliminan archivos gestionados por este instalador.

## Privacidad y límites

No se crean listeners de red, servicios en la nube ni sesiones de modelo adicionales. La navegación y los ajustes utilizan la conexión autenticada de DSH y archivos privados del usuario. Las preguntas y aprobaciones se almacenan temporalmente para mostrar los formularios y no se incluyen en los diagnósticos. No adjuntes estados locales, tokens, conversaciones ni capturas con datos reales sin ocultar al informar de problemas.

macOS controla las notificaciones, los modos de concentración y las vistas de la pantalla bloqueada. El silencio no aprueba, rechaza ni responde automáticamente. Se admite un Host/directorio de estado local activo. Compartirlo entre varios Hosts, macOS antiguos e Intel no se han verificado en equipos reales. La aceptación local existente cubre expansión del menú, navegación reciente, conservación de borradores, borrado de respuestas y retirada al responder o cancelar en DSH; no acredita aceptación real en todos los idiomas.

## Desarrollo y verificación

```sh
npm ci --ignore-scripts
npm test
npm run test:native
npm run check:release
```

El archivo completo incluye pruebas, archivos de bloqueo, CI y scripts de compilación. El `.tgz` incluye el código de ejecución y del asistente, sin toda la batería de pruebas. Consulta el [procedimiento de publicación](docs/release.md) y el [historial](CHANGELOG.md).

## Licencia

[MIT](LICENSE). El nombre DSH y el icono oficial obtenido localmente identifican la integración y no conceden derechos sobre marcas de terceros. Los recursos de representación y sus licencias figuran en [THIRD_PARTY](THIRD_PARTY.md).
