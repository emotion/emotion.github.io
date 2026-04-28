---
title: "header with underline name in nginx"
date: 2017-03-20
tags: [Nginx, HTTP, Header]
draft: true
---

http://stackoverflow.com/questions/22856136/why-underscores-are-forbidden-in-http-header-names

If you do not explicitly set underscores_in_headers on;, nginx will silently drop HTTP headers with underscores (which are perfectly valid according to the HTTP standard). This is done in order to prevent ambiguities when mapping headers to CGI variables, as both dashes and underscores are mapped to underscores during that process.
