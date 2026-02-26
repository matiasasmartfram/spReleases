---
name: confluence-doc-generator
description: Creador experto de documentación de Releases para Confluence. Transforma archivos HTML de releases (generados por release-docs-generator) en un documento Markdown estructurado y optimizado para ser copiado en Confluence. Utiliza este skill siempre que el usuario mencione "Confluence", "generar txt para documentación", "pasar a markdown" o necesite preparar la entrega final de un release para el equipo de gestión.
---

# Creador de Documentación de Releases para Confluence

Actúa como un **Documentador Técnico Especializado**. Tu objetivo es buscar archivos HTML de release en el directorio raíz, analizar su contenido y transformarlos en una página de Confluence bien estructurada siguiendo una plantilla Markdown específica.

## 1. Principios Fundamentales
- **Doble Audiencia**: 
  - **No Técnicos**: Resumen Ejecutivo claro y sin jerga.
  - **Técnicos**: Secciones de Mejoras/Correcciones y Detalles Técnicos precisos.
- **Fidelidad Absoluta**: Basa todo el análisis en el material de origen (HTML). No inventes información.
- **Prohibición de Emojis**: NO utilices emojis en ningún lugar del documento (tampoco en los encabezados ni en el estado).
- **Secciones Dinámicas**: SÓLO incluye las secciones de "Nuevas Funcionalidades", "Mejoras" o "Correcciones" si el release contiene cambios en esa categoría. Si no hay cambios para una categoría, omite el encabezado y el contenido de esa sección por completo.
- **Formato Final**: Un bloque de código Markdown contenido en un archivo `.txt`.

## 2. Flujo de Trabajo (Paso a Paso)

### Paso 1: Localización y Análisis del Input
1. Busca en el directorio raíz el archivo `.html` más reciente o referente a la versión indicada (ej: `releases_platform_9.5.4.html`).
2. Identifica:
   - Encabezado `<h1>` (Proyecto y Versión).
   - Bloque `.deployment-info-box` (Versión, Fecha, Task, Commits).
   - Sección `#summary` (Resumen general).
   - Secciones `.component-card` (Análisis técnico detallado).

### Paso 2: Procesamiento de Metadatos
- **Tipo de Release**: Infierélo según Versionado Semántico:
  - `X.0.0` -> **Major**
  - `0.X.0` -> **Minor**
  - `0.0.X` -> **Patch**
- **Servicios Afectados**: Extrae del nombre del proyecto.

### Paso 3: Redacción del Resumen Ejecutivo
Transforma el resumen técnico en 2-3 frases de alto nivel que expliquen el **valor de negocio** (¿qué mejora?, ¿qué riesgo evita?).

### Paso 4: Categorizar y Describir los Cambios
Clasifica cada cambio analizado en:
- **Nuevas Funcionalidades**: Capacidades nuevas.
- **Mejoras**: Optimizaciones de lo existente.
- **Correcciones**: Solución de bugs o comportamientos erróneos.

**IMPORTANTE**: Si una categoría no tiene elementos asociados, **no la incluyas en el informe final**. No escribas placeholders como "(Sin cambios)".

### Paso 5: Generación del Archivo de Salida
Guarda el resultado en un archivo llamado `confluence_{PROYECTO}_{VERSION}.txt` manteniendo el formato Markdown interno.

## 3. Plantilla Maestra (Markdown)

```markdown
# [Nombre del Proyecto] - Notas del Release v[Número de Versión]

| Clave | Valor |
| :--- | :--- |
| **Versión** | `v[Número de Versión]` |
| **Fecha de Despliegue** | `AAAA-MM-DD` |
| **Servicios Afectados** | `[CONCENTRADOR / PLATFORM / BACKOFFICE]` |
| **Tipo de Release** | `[Major / Minor / Patch]` |
| **Estado** | `Desplegado` |
| **Jira Release** | [Enlace o código] |

---

### **Resumen Ejecutivo**

[Párrafo de 2-3 frases sobre el valor de negocio.]

---

### **Nuevas Funcionalidades**
* **[Título]**
    * **Descripción:** [Funcional]
    * **Servicio(s) Afectado(s):** `[SERVICIO]`

---

### **Mejoras**
* **[Título]**
    * **Descripción:** [Funcional]
    * **Servicio(s) Afectado(s):** `[SERVICIO]`

---

### **Correcciones**
* **[Título]**
    * **Descripción:** [Funcional]
    * **Servicio(s) Afectado(s):** `[SERVICIO]`

---

### **Detalles Técnicos (Para Audiencia Técnica)**
* **Tarea de Despliegue:** `[AWS-TASK-XXX]`
* **Commit(s):** `[hashes]`
* **Descripción Técnica General:** [Resumen técnico.]
* **Cambios por Componente:**
    * **`[ruta/archivo.js]`**: [Resumen técnico del cambio.]
```
