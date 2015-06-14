---
author: Greg Rahn
comments: true
date: 2009-12-14T16:00:20.000Z
layout: post
slug: the-core-performance-fundamentals-of-oracle-data-warehousing-introduction
title: The Core Performance Fundamentals Of Oracle Data Warehousing - Introduction
wp_id: 668
wp_categories:
  - Data Warehousing
  - Exadata
  - Oracle
  - Performance
  - VLDB
wp_tags:
  - data warehouse
  - Data Warehousing
  - Oracle
  - Performance
---

At the 2009 [Oracle OpenWorld Unconference](http://wiki.oracle.com/page/Oracle+OpenWorld+Unconference) back in October I lead a chalk and talk session entitled _The Core Performance Fundamentals Of Oracle Data Warehousing_.  Since this was a chalk and talk I spared the audience any powerpoint slides but I had several people request that make it into a presentation so they could share it with others.  After some thought, I decided that a series of blog posts would probably be a better way to share this information, especially since I tend to use slides as a speaking outline, not a condensed version of a white paper.  This will be the first of a series of posts discussing what I consider to be the key features and technologies behind well performing Oracle data warehouses.

### Introduction

As an Oracle database performance engineer who has done numerous customer data warehouse benchmarks and POCs over the past 5+ years, I've seen many data warehouse systems that have been plagued with problems on nearly every DBMS commonly used in data warehousing. Interestingly enough, many of these systems were facing many of the same problems. I've compiled a list of topics that I consider to be key features and/or technologies for Oracle data warehouses:

### Core Performance Fundamental Topics

- [Balanced Hardware Configuration](/2009/12/22/the-core-performance-fundamentals-of-oracle-data-warehousing-balanced-hardware-configuration/)
- [Table Compression](/2010/01/19/the-core-performance-fundamentals-of-oracle-data-warehousing-table-compression/)
- [Partitioning](/2010/01/25/the-core-performance-fundamentals-of-oracle-data-warehousing-partitioning/)
- [Parallel Execution ](/2010/04/19/the-core-performance-fundamentals-of-oracle-data-warehousing-parallel-execution/)
- [Data Loading](/2010/04/23/the-core-performance-fundamentals-of-oracle-data-warehousing-data-loading/)
- [Row vs. Set Processing](/2010/07/20/the-core-performance-fundamentals-of-oracle-data-warehousing-%E2%80%93-set-processing-vs-row-processing/)
- Indexing and Materalized Views

In the upcoming posts, I'll deep dive into each one of these topics discussing why these areas are key for a well performing Oracle data warehouse.  Stay tuned...
