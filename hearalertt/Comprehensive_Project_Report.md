# Comprehensive Project Report: HearAlert
**AI-Powered Environmental Awareness for the Deaf and Hard-of-Hearing**

---

## 1. Introduction

For individuals who are deaf or hard-of-hearing (DHH), navigating a world dominated by auditory cues—such as emergency sirens, fire alarms, and honking vehicles—presents continuous challenges and safety risks. 

**HearAlert** is an AI-powered mobile application designed to bridge this crucial sensory gap. By leveraging real-time machine learning (ML) audio classification through on-device processing, HearAlert acts as a continuous "digital ear." When a critical sound is detected (e.g., car horns, alarms), the app instantaneously translates the audio event into multi-sensory physical alerts, including customized haptic vibration patterns and high-visibility camera strobe flashes, ensuring the physical safety and independence of the user.

---

## 2. Problem Statement and Objectives

### Problem Statement
Over 430 million people worldwide experience disabling hearing loss. Current assistive technologies meant to alert these individuals to acoustic dangers rely heavily on static, specialized hardware (e.g., hardwired strobe fire alarms) that are prohibitively expensive and offer no protection outside the home. Meanwhile, software-based solutions that rely on cloud servers suffer from severe latency and fail in areas without Wi-Fi or cellular networks, making them unreliable for life-or-death emergencies. There is an urgent need for an accessible, portable, offline software solution utilizing ubiquitous hardware (smartphones).

### Objectives
1.  **Ultra-Low-Latency Edge Processing:** To implement a lightweight audio ingestion engine across an on-device neural network (TensorFlow Lite), processing audio with near-zero latency without internet reliance.
2.  **High-Precision AI Classification:** To deploy a dual-model Artificial Intelligence pipeline capable of hyper-accurate classification of critical safety sounds (Fire Alarms, Sirens, Car Horns, Baby Crying, Glass Breaking).
3.  **Context-Aware Filtering (Smart Zoning):** To dynamically suppress irrelevant alerts based on the user's situation to prevent alert fatigue.
4.  **Multi-Sensory Dispatching:** To translate AI inferences into immediate physical actions via distinct vibration patterns and visual LED strobes.

---

## 3. System Analysis

The HearAlert system shifts the paradigm from hardware-bound sensory aids to a purely mobile, software-defined architecture. 

### Existing System Disadvantages vs Proposed System
| Feature | Existing Systems | Proposed System (HearAlert) |
| :--- | :--- | :--- |
| **Hardware Requirement** | Requires proprietary vibration pads and wired strobes | Software-only; utilizes the user's existing smartphone hardware |
| **Portability** | Confined to a single room or building | 100% portable; protects users in any environment (street, home, office) |
| **Processing Reliance** | Cloud APIs (high latency, breaks entirely when offline) | Edge Computing processing locally entirely offline |

### Key Performance Metrics (KPIs)
*   **End-to-End Latency:** < 1000ms from physical sound wave entering microphone to hardware vibration triggering.
*   **Model Accuracy:** > 85% accuracy for Critical Safety sounds to minimize false negatives in dangerous situations.

---

## 4. System Design

### 4.1 Data Flow Diagram (DFD)
![Level 0 DFD](02_Level0_DFD.png)

The Level 0 Data Flow Diagram depicts the fundamental concept of HearAlert: the app acts as a sensory bridge, ingesting standard real-world acoustic waves and dispatching translated physical haptic and visual signals directly to the user.

### 4.2 UML Use Case Diagram
![UML Use Case Diagram](04_UseCase_Diagram.png)

The Use Case models the primary interactions. The DHH user initializes the microphone monitoring, sets their preferred sensory outputs (haptic intensity/strobes), establishes their Smart Zone context, and reviews historical analytics.

### 4.3 Architecture Diagram
![System Architecture Diagram](01_System_Architecture.png)

HearAlert utilizes a **Pipes-and-Filters Edge Architecture**. Raw hardware microphone streams are pushed into a temporary buffer. This buffer is read by a dual-stage neural network (leveraging YAMNet) on the Mobile Processor. Validated results that pass the confidence gateway are immediately pushed to the Alert Hardware engine to trigger the device's vibration motors and LED strobe.

---

## 5. List of Modules

The HearAlert application is modularized into five core components that operate asynchronously to ensure real-time performance:

1.  **Audio Ingestion & Buffer Module:** Interfaces directly with the device microphone natively. It captures continuous audio streams and chunks them into precise 0.975-second buffers required by the ML model.
2.  **Machine Learning Inference Module:** The "Brain" of the app. It runs the quantized `.tflite` YAMNet model on the edge. It takes the audio buffers, extracts spectrogram features, and outputs an array of confidence scores for hundreds of potential sounds.
3.  **Alert Dispatcher Module:** The "Muscle" of the app. Once a critical sound passes the confidence threshold, this module directly interfaces with the iOS/Android hardware APIs to trigger complex haptic vibration patterns and activate the camera flash relay.
4.  **Context & Filtering Module:** Acts as a gatekeeper to prevent alert fatigue. It suppresses continuous identical sounds (cooldowns) and manages "Smart Zones" (e.g., ignoring 'dog bark' if the user disabled it).
5.  **User Interface (UI) Module:** The Flutter-based frontend containing the Neural Audio HUD, settings management, history logs, and the aesthetic LED-style visual spectrum analyzer.

---

## 6. Output of Module (Machine Learning & Dispatcher Integration)

To verify the successful integration of the core system modules, the following is the standard terminal console output when the app is actively listening and correctly detects a critical life-safety sound (a Fire Alarm):

**Console Execution Trace:**
```text
[INFO] HearAlert Audio Service Initialized.
[INFO] Microphone access GRANTED. Sample rate: 16000Hz.
[PROCESS] Starting continuous inference loop...
[BUFFER] Ingested 15600 linear PCM samples.
[ML_ENGINE] Running TFLite Inference...
[DETECT] Background Noise : 12%
[DETECT] Speech           : 5%
[DETECT] Fire Alarm       : 94%  <-- CRITICAL THRESHOLD MET
[FILTER] Sound event 'fire_alarm' passed cooldown check.
[DISPATCH] Triggering hardware 'HEAVY_IMPACT' haptic sequence.
[DISPATCH] Strobing camera LED (pattern: SOS).
[LOG] Database entry successfully saved: "Fire Alarm at 14:32:01".
[PROCESS] Resuming continuous inference loop...
```
