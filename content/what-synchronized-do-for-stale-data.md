---
title: "what synchronized do for stale data?"
date: 2016-05-26
tags: [Java, CPU, Cache, Synchronized]
draft: false
---
对于使用同一个锁的sync block，block之前和之中进行的数据修改，在block块结束之后，都可以在其它线程的sync block中可见。
原理应该是和volatile类似，volatile是在数据写入的时候，将数据写入main memory中，并且同时将cpu其它core的这个数据的cache置失效
而sync在结束之后，会将线程所在的core的cache的stale data都写入main memory中，同时会将其它core的这些stale data对应的cache置失效
  (ps: cache被置失效之后，下次读取该数据的时候，就必须到main memory进行读取，所以会读到最新的数据.)
we are java developers, we only know virtual machines, not real machines!
let me theorize what is happening - but I must say I don't know what I'm talking about.
say thread A is running on CPU A with cache A, thread B is running on CPU B with cache B

* thread A reads y; CPU A fetches y from main memory, and saved the value in cache A.
* thread B assigns new value to 'y'. VM doesn't have to update the main memory at this point; as far as thread B is concerned, it can be reading/writing on a local image of 'y'; maybe the 'y' is nothing but a cpu register.
* thread B exits a sync block and releases a monitor. (when and where it entered the block doesn't matter). thread B has updated quite some variables till this point, including 'y'. All those updates must be written to main memory now.
* CPU B writes the new y value to place 'y' in main memory. (I imagine that) almost INSTANTLY, information 'main y is updated' is wired to cache A, and cache A invalidate its own copy of y. That must have happened really FAST on the hardware.
* thread A acquires a monitor and enters a sync block - at this point it doesn't have to do anything regarding cache A. 'y' has already gone from cache A. when thread A reads y again, it's fresh from main memory with the new value assigned by B.
* consider another variable z, which was also cached by A in step(1), but it's not updated by thread B in step(2). it can survive in cache A all the way to step(5). access to 'z' is not slowed down because of synchronization.

if the above statements make sense, then indeed the cost isn't very high.

ref: http://stackoverflow.com/questions/1850270/memory-effects-of-synchronization-in-java