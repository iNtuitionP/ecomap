# ecomap

# 🌍 에코지도 찌릿 (EcoMap Jjirit)

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi)
![TensorFlow](https://img.shields.io/badge/TensorFlow-2.x-FF6F00?logo=tensorflow)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-PostGIS-336791?logo=postgresql)

> **"기술을 통해 일상 속 플라스틱 처리를 즐거운 습관으로 바꾼다."** <br>
> 대학생 및 1인 가구를 위한 AI 기반 플라스틱 분리배출 가이드 및 위치 기반 수거함 매핑 플랫폼입니다.

---

## 📑 목차 (Table of Contents)
1. [프로젝트 개요](#-프로젝트-개요)
2. [핵심 기능](#-핵심-기능-key-features)
3. [시스템 아키텍처](#-시스템-아키텍처-architecture)
4. [데이터베이스 구조 (ERD)](#-데이터베이스-구조-erd)
5. [기술 스택](#-기술-스택-tech-stack)
6. [폴더 구조](#-폴더-구조-directory-structure)
7. [설치 및 실행 방법](#-설치-및-실행-방법-getting-started)
8. [환경 변수 설정](#-환경-변수-설정-env)

---

## 📖 프로젝트 개요
'에코지도 찌릿'은 헷갈리는 복합 재질 플라스틱의 정확한 분리배출 방법을 AI 객체 인식을 통해 실시간으로 안내하고, 사용자 위치를 기반으로 가장 가까운 재활용 수거함을 매핑해주는 서비스입니다. 올바른 분리배출 실천 시 '에코 포인트'를 지급하여 지속적인 환경 보호 활동을 장려합니다.

---

## ✨ 핵심 기능 (Key Features)

### 1. 🤖 AI 지능형 분리배출 가이드
* **객체 인식 및 재질 분류:** 스마트폰 카메라로 플라스틱 용기를 스캔하면 딥러닝 모델(MobileNetV3)이 재질(PET, PP, PS 등)을 자동 분류합니다.
* **맞춤형 행동 지침:** 오염도에 따른 세척 가이드, 라벨 제거 여부 등 환경부 표준 가이드라인을 제공합니다.

### 2. 🗺️ 위치 기반 에코 지도 (GIS Mapping)
* **실시간 수거함 위치 조회:** 광명시 공공데이터를 연동하여 가로 쓰레기통 및 재활용 수거함 위치를 지도 상에 표시합니다.
* **최적 경로 안내:** 현재 위치에서 가장 가까운 수거함까지의 도보 최적 경로를 제공합니다.

### 3. 🎁 에코 포인트 & 게이미피케이션
* **리워드 시스템:** 배출 인증 시 에코 포인트 적립 (추후 지역 화폐 연동 예정).
* **탄소 절감 리포트:** 나의 활동이 가져온 실질적인 CO2 감소 효과 시각화 리포트 및 랭킹 제공.

---

## 🏗️ 시스템 아키텍처 (Architecture)

```mermaid
graph TD
    Client[Mobile App - Flutter] -->|REST API| API_Gateway[API Gateway - FastAPI]
    
    subgraph Backend Services
        API_Gateway --> Auth[Auth Service]
        API_Gateway --> AI[AI Image Service]
        API_Gateway --> Map[GIS Map Service]
        API_Gateway --> Reward[Point Service]
    end
    
    AI --> Model[TensorFlow/MobileNetV3]
    Auth --> Firebase[Firebase Auth]
    
    Map --> DB[(PostgreSQL + PostGIS)]
    Reward --> DB
    Auth --> DB
    
    Map --> ExternalAPI[광명시 공공데이터 API]
