---
title: "ServletRequest 和 HttpServletRequest"
date: 2017-01-15
tags: [Java, ServletRequest, HttpServletRequest, Tomcat, Spring]
draft: true
---
## ServletRequest和HttpServletRequest
* 当我们需要自己写filter的时候，我们经常会遇到的接口会有ServletRequest和HttpServletRequest，类似的还有ServletResponse和HttpServletResponse
  * 例如Filter接口的doFilter(SerlvetRequest request, SerlvetResponse response, FilterChain chain);
  * 还有OncePerRequestFilter的doFilterInternal(
			HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)；
* 我们可以看到这里使用了不同的ServletRequest和HttpServletRequest，而且也经常看到直接将ServletRequest强转为HttpServletRequest的代码。这就让人很迷惑了，既然可以强转HttpServletRequest，为什么不直接使用HttpServletRequest呢？
* 这两个接口名字上的区别就是Http，所以我的感觉是：是不是还有其它协议的ServletRequest，但是在代码中查找却找不到其它协议的ServletRequest接口。
* 不过通过万能的Google，我找到了一个答案https://coderanch.com/t/621449/java/Difference-ServletRequest-HttpServletRequest
```
Hi Everyone 

I have couple of doubts, they are as follows: 
Que1 - What is the difference between the request/ response objects of these two interfaces (ServletRequest & HttpServletRequest) ? 
Que2 - When a request is send from client to the server, then that request object is whose object ServletRequest or HttpServletRequest ? 
```
```
1. Http. Servlets are actually generic components designed to support any sort of operation that operates in a request/response cycle. That mostly means HTTP, but ages ago, IBM mainframes routinely did their online apps in a framework known as CICS (Customer Information Control System). It didn't use tcp/ip (not invented yet), and it didn't use HTML or HTTP (also not invented yet), but it was (mostly) request/response. So had servlets - or Java - existed back then, they would have been appropriate. 

What an HttpServlet adds to the core servlet class is support for things specific to HTTP. For example, how URLs are processed, the difference between request types (GET, POST, HEAD, DELETE and so forth). 

2. Both (an HttpServletRequest is a subclass of ServletRequest). When an HTTP client sends an HTTP(S) URL request to a J2EE webapp server, the server digests the incoming request and constructs an HttpServletRequest and corresponding HttpServletResponse object. Among other things, such as matching up sessions, if applicable. 

Don't forget that all of the above are Interfaces, not classes, so the server's specific implementation class will implement the interface, but its properties and behaviours above and beyond what those interfaces demand are server-specific.
```

* 由此我们可以知道，真的是有其它协议的ServletRequest的。ServletRequest是为了更通用的目的（不只是HTTP）而设计的接口，很久很久以前IBM主机上一个框架CICS就有他们专门的协议，这协议也是兼容ServletRequest这个接口的
* 按照这个情况的话，那么ServletRequest和HttpServletRequest这个设计是没有问题的，只是在如今，在tomcat上，我们通常的情况都是默认使用的是HTTP协议，用的是HttpServletRequest，所以强制转ServletRequest为HttpServletRequest是没有问题的。