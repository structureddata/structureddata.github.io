---
author: Greg Rahn
comments: true
date: 2007-03-05T15:56:39.000Z
layout: post
slug: got-root-cause
title: Got Root Cause?
wp_id: 7
wp_categories:
  - Troubleshooting
---

Many of us have been in a situation where the performance of our [Oracle database](http://www.oracle.com/database/index.html) has degraded.  Ultimately, we are looking to correctly diagnose the [root cause](http://en.wikipedia.org/wiki/Root_cause) and resolve the performance issue.  This is frequently easier said than done.  I'd like to offer a few thoughts on the topic that hopefully will make correctly diagnosing root cause easier and more frequent for you.

### 1. Have a clear and concise definition of the perceived problem.
This sounds simple, but I think it is more challenging than one might expect.  Being able to accurately communicate the problem is extremely important, especially when involving a support group or other third party.  There should be a concise problem description and all involved groups should agree with it.

### 2. Try to categorize the observations as a potential cause or a symptom.
I personally believe this is one of the most important recommendations.  It is often challenging to determine if a performance observation is a cause or a symptom.  In times like this I find it very productive to create a list of my observations at the different levels: host/system, database, application, etc.  Once all of the observations are documented, relationships between them often become more apparent.  Remember, it's better to spend more time and correctly diagnose an observation than to prematurely label it incorrectly.

### 3. Be detail oriented, but do not become too obsessed with any one detail.
It's important to pay close attention to the details, but do not lose sight of the overall picture.  This is especially important when it is unknown whether a given observation is a potential cause or a symptom.  You don't want to spend too much time trying to treat the symptoms - we're after the root cause.

### 4. Create a simple, reproducible test case.
Having a test case is often times required if an external group will be involved with the problem resolution.  This will allow them to troubleshoot the issue in a non-critical environment and focus on the issue without worrying about its impact on the users.  I understand that this isn't always possible, but a best effort should be made to obtain a test case.

### 5. Make one and only one change at a time.
Like math equations, performance issues are more easily solved when as many variables as possible are held constant.  Making only one change at a time will give clarity to the change's impact on the performance issue.
