---
author: Greg Rahn
comments: true
date: 2009-11-24
layout: post
slug: oracle-11gr2-database-flash-cache-patch-for-oracle-enterprise-linux
title: Oracle 11gR2 Database Flash Cache Patch For Oracle Enterprise Linux
wp_id: 694
wp_categories:
  - 11gR2
  - Oracle
wp_tags:
  - 11gR2
  - database flash cache
---

Just a quick note that there is now a patch for the 11.2 Oracle Enterprise Linux (OEL) database ports to enable the database flash cache (not to be confused with the Exadata flash cache).  Go to the My Oracle Support site [[link](https://supporthtml.oracle.com/ep/faces/secure/ml3/patches/ARUPatchDownload.jspx)] and search for patch 8974084 - META BUG FOR FLASH CACHE 11.2PL BUGS TO BACKPORT TO 11.2.0.1 OEL

You can download Oracle Database 11g Release 2 from [OTN](http://www.oracle.com/technology/software/products/database/index.html).

**Note:** The db flash cache is already built into the Solaris ports so no patch is needed.
