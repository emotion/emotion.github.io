---
title: "what synchronized do for stale data?"
date: 2016-05-26
tags: [Java, CPU, Cache, Synchronized]
draft: false
---

## 问题

`synchronized` 为什么能解决 stale data？

标准说法是：

> 对同一个锁来说，一个线程释放锁之前的修改，对之后拿到同一把锁的线程可见。

这句话是对的，但是有点抽象。

我更想用一个接近硬件的方式理解它：**为什么线程 A 原来可能读到旧数据，加了 synchronized 之后就不能继续读旧数据？**

---

## 一个简单模型

假设有两个线程：

```text
Thread A running on CPU A, with Cache A
Thread B running on CPU B, with Cache B
```

还有一个共享变量：

```java
int y = 0;
```

可能发生这样的事情：

1. Thread A 读过 `y`，CPU A 把 `y` 缓存在 Cache A 里；
2. Thread B 修改了 `y`，比如把 `y` 改成 `1`；
3. 如果没有同步，Thread A 之后再读 `y`，理论上可能继续用自己这边的旧值；
4. 如果 Thread B 在 synchronized 块里修改 `y`，并且退出 synchronized；
5. Thread A 后面进入同一把锁保护的 synchronized 块再读 `y`，就必须看到 Thread B 释放锁前的修改。

也就是说，`synchronized` 做的事情可以简单理解为：

```text
释放锁：把我之前做过的修改发布出去
获取锁：我要重新看一下别人发布过的修改
```

这不是严格的 JVM 实现描述，但作为理解模型很有用。

---

## 不是所有 synchronized 都有用，必须是同一把锁

关键点是：**必须使用同一把锁。**

比如这样是可以建立可见性关系的：

```java
synchronized (lock) {
    y = 1;
}

synchronized (lock) {
    System.out.println(y);
}
```

前一个 synchronized 释放的是 `lock`，后一个 synchronized 获取的也是 `lock`。

但是下面这样不行：

```java
synchronized (lock1) {
    y = 1;
}

synchronized (lock2) {
    System.out.println(y);
}
```

因为 `lock1` 和 `lock2` 不是同一把锁。

---

## 从硬件角度可以怎么想

可以把 CPU cache 想成每个 CPU core 自己手边的小本子。

Thread A 在 CPU A 上读过 `y`，CPU A 的小本子里可能记着：

```text
y = 0
```

Thread B 在 CPU B 上把 `y` 改成：

```text
y = 1
```

如果没有任何同步机制，Thread A 什么时候能看到这个新值，就不是 Java 程序可以依赖的事情。

`synchronized` 的作用就是在加锁和解锁的位置，加上一些约束：

1. Thread B 释放锁之前，不能把 `y = 1` 这个修改藏着不让别人看到；
2. Thread A 获取同一把锁之后，不能继续假装自己以前看到的旧值还有效；
3. JVM 和 CPU 要配合保证这个结果成立。

底层可能会用到：

- 禁止某些指令重排；
- memory barrier；
- CPU cache 一致性协议；
- 必要时让其它 CPU core 上的旧 cache line 失效。

但作为 Java 开发者，不需要把这些细节全部记住。

可以先记住这个简单模型：

```text
unlock：发布之前的修改
lock：接收别人发布的修改
```

---

## 不要理解成清空所有 cache

原来我容易把它想成：

> synchronized 退出时，把当前 CPU cache 里的数据全部写回 main memory，然后让其它 CPU 的 cache 全部失效。

这个理解太重了，也不准确。

更好的理解是：

> synchronized 只需要保证和这把锁相关的可见性语义成立。底层可能通过 cache 一致性和内存屏障实现，但不是每次都清空整个 CPU cache。

也就是说：

1. 不是整个 cache 都被清空；
2. 通常是 cache line 粒度，不是 Java 变量粒度；
3. 也不一定真的写回到内存条，CPU 之间也可能直接传递 cache line；
4. 没有被修改、也没有冲突的数据，不会因为 synchronized 就全部失效。

所以 synchronized 有成本，但不是“清空全世界”的成本。

---

## 和 volatile 的类比

`volatile` 也能解决可见性问题。

可以简单类比：

```text
volatile write：发布这个变量的新值
volatile read：读取别人发布的新值
```

而 synchronized 是：

```text
unlock：发布这个锁保护范围内的修改
lock：读取这个锁保护范围内别人发布过的修改
```

区别是：

- `volatile` 不加锁，不保证互斥；
- `synchronized` 会加锁，保证同一时间只有一个线程进入临界区；
- `synchronized` 更适合保护一组变量；
- `volatile` 更适合单个状态标记。

---

## 对 StackOverflow 那段解释的理解

原文里这几句话很有意思：

> we are java developers, we only know virtual machines, not real machines!  
> let me theorize what is happening - but I must say I don't know what I'm talking about.

我的理解是：

我们可以用 CPU cache 的模型帮助理解 synchronized，但不要把这个模型当成 Java 规范。

Java 真正保证的是：

```text
同一把锁：unlock 之前的修改，对后续 lock 之后的代码可见
```

硬件上大概可以想成：

```text
Thread B 修改 y
-> Thread B 释放锁，把修改发布出去
-> Thread A 获取同一把锁
-> Thread A 不能继续读旧的 y
```

这个模型已经足够帮助理解 synchronized 为什么能解决 stale data。

---

## 小结

`synchronized` 解决 stale data，可以先这样理解：

```text
同一把锁上：
一个线程 unlock，就是发布之前的修改；
另一个线程 lock，就是接收这些修改。
```

底层 JVM 和 CPU 可能通过 memory barrier、cache 一致性协议、禁止指令重排等方式来实现。

但我们不需要把它理解成“每次 synchronized 都清空所有 CPU cache”。

更简单的理解是：

> synchronized 在同一把锁的释放和获取之间，建立了一条可见性通道。

ref: http://stackoverflow.com/questions/1850270/memory-effects-of-synchronization-in-java
