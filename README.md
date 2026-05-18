# 🏍️ Moto Care - App de Gestión de Mantenimiento

# 🏍️ Moto Care - App de Gestión de Mantenimiento

[![Prueba la App en Vivo](https://img.shields.io/badge/Prueba_la_App_en_Vivo-Fluorescente?style=for-the-badge&logo=flutter&color=02569B)](https://josemanueldg02-star.github.io/moto_care/)

Una aplicación móvil Full-Stack desarrollada en **Flutter** diseñada para la gestión integral y el control de gastos del mantenimiento de motocicletas. Este proyecto destaca por su integración robusta con servicios en la nube (AWS) y un diseño centrado en la experiencia de usuario (UX).

## 🛠️ Stack Tecnológico

* **Frontend Mobile:** Flutter, Dart
* **Autenticación:** Amazon Cognito
* **Base de Datos y Nube:** AWS Amplify, GraphQL (Sincronización en tiempo real)
* **Almacenamiento de Archivos:** Amazon S3 (Gestión de recibos y facturas)
* **Control de Versiones:** Git / GitHub

## ✨ Características Principales

* **Autenticación Segura:** Sistema de login y registro gestionado integralmente mediante AWS Cognito.
* **Gestión Documental Cloud:** Subida, lectura y almacenamiento de recibos de piezas y talleres directamente en *buckets* de Amazon S3.
* **Dashboard Financiero:** Implementación de gráficos dinámicos que muestran el gasto anual en mantenimiento.
* **Búsqueda Avanzada:** Motor de búsqueda en tiempo real para localizar rápidamente mantenimientos pasados.
* **UI/UX y Personalización:** Arquitectura de interfaz reactiva con persistencia de datos local y soporte completo para **Modo Oscuro (Dark Mode)**.

## 🏗️ Arquitectura
El proyecto aplica principios de diseño modular, combinando el árbol de widgets de Flutter con la potencia del ecosistema *Serverless* de Amazon Web Services. El uso de GraphQL permite operaciones eficientes de consulta y mutación de datos desde el dispositivo móvil.

---
**Autor:** Jose Manuel Dominguez Garcia
**Repositorio:** [https://github.com/josemanueldg02-star/moto_care](https://github.com/josemanueldg02-star/moto_care)