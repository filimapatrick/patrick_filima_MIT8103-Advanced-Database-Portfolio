# MIT 8103 – Advanced Database Systems Portfolio

## African Neuroimaging Research Data Management System (ANRDMS)

### Student Information

- **Name:** Patrick Filima
- **Student ID:** 301900778
- **Institution:** Miva Open University
- **Programme:** Master of Information Technology
- **Course:** MIT 8103 – Advanced Database Systems
- **Academic Session:** 2026/2027
- **Cohort:** September 2026

## 1. Project Overview

The African Neuroimaging Research Data Management System (ANRDMS) is a simulated research database designed to support the management of brain imaging data collected across multiple healthcare and research institutions in Nigeria.

Neuroimaging research generates large amounts of information, including participant demographics, MRI scan metadata, neurological diagnoses, scanner specifications, image-processing results and quality control records. Managing these data across multiple research sites presents challenges related to data consistency, efficient retrieval, security and scalability.

This project explores how advanced database technologies can address these challenges through relational database design, query optimisation, transaction management, NoSQL modelling and distributed database architecture.

## 2. Selected Organisation / Case Study

The selected case study is a simulated multi-site neuroimaging research organisation operating across Nigeria.

The system is inspired by the challenges of managing clinical and research MRI data across different hospitals and research centres.

All participant records used in this project will be synthetic and created specifically for academic demonstration. No confidential patient information will be used.

## 3. System Users

- Neuroimaging researchers
- Radiologists and imaging technicians
- Research data managers
- Database administrators
- Neuroinformatics developers

## 4. Major Data to Be Stored

- Research participant demographics
- Hospitals and research sites
- MRI scanner specifications
- Neurological diagnoses
- MRI scan metadata and imaging sequences
- Research projects
- Image-processing jobs
- Quality control results

## 5. Key Database Operations

- Register research participants and research sites.
- Record MRI scans and associated scanner information.
- Retrieve imaging records based on diagnosis, site or sequence.
- Track image-processing jobs and quality control outcomes.
- Execute and manage concurrent database transactions.
- Store flexible MRI metadata using NoSQL documents.
- Support data availability across multiple research sites.

## 6. Technologies

| Technology        | Purpose                                     |
| ----------------- | ------------------------------------------- |
| PostgreSQL        | Relational database implementation          |
| SQL               | Database queries and transaction management |
| MongoDB           | NoSQL document database                     |
| GitHub            | Version control and portfolio documentation |
| Mermaid / Draw.io | Database and architecture diagrams          |

## 7. Portfolio Structure

| Portfolio       | Description                             | Status        | Deliverables & Artifacts                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| :-------------- | :-------------------------------------- | :------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Portfolio 1** | Database Design and Modelling           | **Completed** | [`portfolio-1-database-design/`](./portfolio-1-database-design/README.md) · [Schema DDL](./portfolio-1-database-design/schema.sql) · [Seed Data](./portfolio-1-database-design/seed_data.sql) · [ERD](./portfolio-1-database-design/er_diagram.mermaid) · [Data Dictionary](./portfolio-1-database-design/data_dictionary.md) · [Normalisation Report](./portfolio-1-database-design/normalisation_report.md) · [Verification Evidence](./portfolio-1-database-design/verification_evidence.md) |
| **Portfolio 2** | Query Processing and Optimisation       | Pending       | [`portfolio-2-query-optimisation/`](./portfolio-2-query-optimisation/README.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **Portfolio 3** | Transactions and Concurrency            | Pending       | [`portfolio-3-transactions-concurrency/`](./portfolio-3-transactions-concurrency/README.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **Portfolio 4** | NoSQL and Advanced Data Models          | Pending       | [`portfolio-4-nosql/`](./portfolio-4-nosql/README.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **Portfolio 5** | Distributed and Cloud Database Exercise | Pending       | [`portfolio-5-distributed-cloud/`](./portfolio-5-distributed-cloud/README.md)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |

## 8. Project Objectives

The objectives of this project are to:

1. Design a normalised relational database for multi-site neuroimaging research.
2. Implement efficient SQL queries and evaluate database performance.
3. Demonstrate transaction management and concurrency control.
4. Implement a NoSQL model for flexible neuroimaging metadata.
5. Explore distributed and cloud database architectures for research data management.

## 9. Academic Integrity

This repository contains individual practical work developed for the MIT 8103 assessment. External resources, datasets, libraries and AI-assisted learning tools will be acknowledged appropriately.

All implementations, experiments and results will be reviewed, tested and verified by the student.

## 10. Author

Patrick Filima

Master of Information Technology

Miva Open University
