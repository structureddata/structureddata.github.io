---
author: Greg Rahn
comments: true
date: 2011-08-28T17:25:44.000Z
layout: post
slug: reading-active-sql-monitor-reports-offline
title: Reading Active SQL Monitor Reports Offline
wp_id: 1514
wp_categories:
  - 11gR1
  - 11gR2
  - Oracle
wp_tags:
  - sql monitor
---

Active SQL Monitor Reports require some files from the Internet to render the report in the browser.  That's no big deal if you have an Internet connection, but what if you do not?  Generally if you load an Active SQL Monitor Report without an Internet connection, you will just see an empty page in your browser.  There is a little trick I use to work around this issue -- it's to have a copy of the required swf and javascript files locally.  Here is how I do that on my Mac assuming a couple of things:

* You know how to turn on the web server/Web Sharing in System Preferences > Sharing
* You know how to get [wget](http://www.gnu.org/s/wget/) (or use [curl](http://curl.haxx.se/) [part of OS X] to mimic the below commands)

```
### assuming you already have the web server running and have wget
cd /Library/WebServer/Documents
wget --mirror http://download.oracle.com/otn_software/emviewers/scripts/flashver.js
wget --mirror http://download.oracle.com/otn_software/emviewers/scripts/loadswf.js
wget --mirror http://download.oracle.com/otn_software/emviewers/scripts/document.js
wget --mirror http://download.oracle.com/otn_software/emviewers/sqlmonitor/11/sqlmonitor.swf
ln -s download.oracle.com/otn_software otn_software
```

Now edit /etc/hosts and add

```
127.0.0.1 download.oracle.com
```

Now when you load an Active SQL Monitor Report it will access those files from your local web server. Don't forget to undo the /etc/hosts entry once you are back on the Internet.  Also, keep in mind that these files may change so re-download them from time to time.

### Option 2 - Firefox

If [Firefox](http://www.mozilla.com/firefox/) is your browser of choice, then there is another option.  Having successfully rendered an Active SQL Monitor Report while online, you can work offline by using File > Work Offline.  This should allow the use of a cached version of the swf and javascript files.
