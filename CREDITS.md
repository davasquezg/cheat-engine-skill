# Créditos y obras de terceros

## Tabla original de Mega Man Star Force Legacy Collection

La tabla `ct-tablas/mmsf-legacy-collection/MEGAMAN_STARFORCE_Legacy_Collection_v8_AOB_build1.0.2.0.CT` es una **obra derivada** de la tabla publicada por su autor original en FearLess Revolution. Se incluye además `build_v8.py`, que reproduce la v8 a partir de la original.

- Hilo: <https://fearlessrevolution.com/viewtopic.php?t=38738>

Todo el mérito por la estructura de entradas, los offsets de cartas, subitems, habilidades y campos de combate, y los nombres de las entradas corresponde al autor original.

**Aportes de este repositorio sobre la tabla original:**
- bases recuperadas para la build 1.0.2.0;
- script `[Resolver]` con firmas AOB y respaldo estático;
- anidado de los grupos bajo el resolver;
- notas de uso: editar desde el mapa, mapa de bytes por borde y avisos de solapamiento de 4 bytes;
- corrección de etiquetas: HP actual, HP base y el campo `+30`;
- cabeceras-script de Noise Gauge y Delete Time en SF3.

Las licencias de este repositorio cubren **solo esos aportes**. Los derechos sobre el contenido de la tabla original siguen siendo de su autor y se respetan los términos que él haya establecido. **Si eres el autor y quieres que se modifique, se condicione o se retire la tabla, abre un *issue*: se atenderá de inmediato.**

## Marcas

*Mega Man*, *Mega Man Star Force* y los nombres de cartas, personajes y objetos son marcas y contenido de CAPCOM. Se mencionan solo para identificar el juego y sus datos. Este proyecto no está afiliado ni respaldado por CAPCOM.

*Cheat Engine* es un proyecto de Eric Heijnen (Dark Byte): <https://cheatengine.org> · <https://github.com/cheat-engine/cheat-engine>.

## Herramientas

El kit usa las bibliotecas [pefile](https://github.com/erocarrera/pefile), [Capstone](https://www.capstone-engine.org/) y [NumPy](https://numpy.org/), cada una bajo su propia licencia. No se redistribuyen en este repositorio.

## Asistencia

Kit, skill y reparación de la tabla desarrollados con ayuda de Claude (Anthropic).
