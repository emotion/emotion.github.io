---
title: "LevelDB 学习笔记"
date: 2025-03-15
tags: [LevelDB, RocksDB, LSM, 存储引擎]
draft: false
---

## 整体理解

LevelDB 是一个基于 **LSM Tree**（Log-Structured Merge Tree）的嵌入式 KV 存储引擎。

它的核心思路是：

1. 写入尽量先变成顺序写；
2. 数据先写到内存结构，再异步落盘成有序文件；
3. 后台通过 compaction 把多个有序文件逐步合并；
4. 用读放大、写放大、空间放大之间的权衡，换取整体性能。

传统 B+Tree 更偏向原地更新，而 LSM Tree 更偏向追加写入。LevelDB 的写入路径基本是：

```text
WriteBatch
  -> WAL / log file
  -> mutable memtable
  -> immutable memtable
  -> Level-0 SSTable
  -> compaction 到更高 level
```

---

## 写入路径

一次写入大致会经过下面几个步骤：

1. 先把更新追加写入 WAL，也就是 log file；
2. 再把同一批更新写入当前的 mutable memtable；
3. memtable 达到阈值后，会被冻结为 immutable memtable；
4. 系统创建新的 WAL 和新的 mutable memtable，继续接收新的写入；
5. 后台线程把 immutable memtable flush 成一个 Level-0 SSTable；
6. 新生成的 SSTable 被记录到 Manifest 中，成为当前版本的一部分；
7. 后续再通过 compaction 把 Level-0 的文件合并到 Level-1 或更高层级。

这里有两个关键点：

- WAL 用于崩溃恢复；
- memtable 用于把随机写转成内存写，后续再批量顺序落盘。

如果进程崩溃，LevelDB 可以通过 MANIFEST 找到当前版本的 SSTable，再重放还没有 flush 成 SSTable 的 log file，恢复 memtable 中的数据。

---

## MemTable 和 Immutable MemTable

LevelDB 的 memtable 通常可以理解成一个有序的内存表，内部实现是 skiplist。

当前正在写入的 memtable 叫 mutable memtable。

当它达到阈值后，LevelDB 不会继续往里面写，而是：

1. 把它转成 immutable memtable；
2. 新建一个 mutable memtable 接收新的写入；
3. 后台把 immutable memtable 写成 SSTable。

所以 immutable memtable 本身不会继续增长，也不是“达到阈值后再写入 Level-0”。真正触发转换的是 mutable memtable 达到阈值。

---

## SSTable

SSTable 是 Sorted String Table，可以理解成一个有序的、不可变的磁盘文件。

它有几个特点：

1. 文件内部 key 有序；
2. 文件一旦生成就不再修改；
3. 查询时可以根据索引和 bloom filter 减少不必要的磁盘读取；
4. 后台 compaction 会读取多个旧 SSTable，合并生成新的 SSTable。

这种不可变文件的设计让写入路径更简单，也方便做版本管理和快照。

---

## 读取路径

一次读请求通常会按新到旧的顺序查找：

```text
mutable memtable
  -> immutable memtable
  -> Level-0 SSTable
  -> Level-1 SSTable
  -> Level-2 SSTable
  -> ...
```

之所以要从新到旧查，是因为同一个 key 可能有多个版本，新的版本会覆盖旧的版本。

LevelDB 通过 sequence number 区分数据版本。每次写入都会带上更大的 sequence number，读取时根据当前读视图选择合适版本。

---

## Level-0 为什么特殊

Level-0 是 memtable flush 后直接生成的层级，因此它和更高层级有一个重要区别：

**Level-0 的 SSTable 之间 key range 可能重叠。**

比如连续 flush 出来的几个 Level-0 文件，可能都包含 `user:100` 到 `user:900` 这一段 key。

而 Level-1 及以上层级，同一层内部的 SSTable 通常保持 key range 不重叠。

这会带来几个影响：

1. 查询 Level-0 时，可能要查多个 SSTable；
2. Level-0 文件过多会明显增加读放大；
3. 从 Level-0 compact 到 Level-1 时，通常需要选出多个互相重叠的 Level-0 文件，再和 Level-1 中重叠的文件一起合并；
4. Level-1 及以上层级做 compaction 时，同一层通常只需要选一个文件，再找下一层 key range 重叠的文件。

所以 Level-0 是写入落盘后的缓冲层，也是读放大比较容易变高的地方。

---

## Compaction 做了什么

Compaction 可以理解成后台整理数据。

它大致做几件事：

1. 选择某一层的一批 SSTable；
2. 找到下一层中 key range 重叠的 SSTable；
3. 把这些文件按 key 顺序归并；
4. 对同一个 key 的多个版本，只保留仍然需要的版本；
5. 丢弃已经被覆盖的旧值；
6. 在安全条件满足时，丢弃不再需要的 deletion marker；
7. 输出新的 SSTable 到下一层；
8. 更新 Manifest，让新版本引用新的 SSTable，并删除旧文件引用。

Compaction 的本质是用后台 I/O 换取更好的查询效率和空间回收。

但是 compaction 本身也会带来写放大，因为同一条数据可能在不同层级之间被反复读出、合并、再写入。

---

## 三种放大

理解 LevelDB 和 RocksDB 时，经常会看到三个概念：

### 读放大

一次查询需要访问多个地方。

比如一个 key 可能要依次查：

```text
memtable -> immutable memtable -> 多个 Level-0 文件 -> Level-1 -> Level-2
```

如果 Level-0 文件太多，读放大会比较明显。

### 写放大

用户写入一份数据，底层实际写入多份数据。

原因是数据先写 WAL，又写 memtable，flush 成 SSTable 后，还可能在 compaction 中被反复合并到更高层级。

### 空间放大

同一个 key 的旧版本、删除标记、尚未 compact 的重复数据会暂时占用额外空间。

Compaction 会逐步降低空间放大，但不会完全免费，因为它需要消耗后台 I/O 和 CPU。

---

## RocksDB 相比 LevelDB 的一些改进

RocksDB 可以看成是在 LevelDB 思路上，为更复杂生产场景做了大量增强。

### 1. Compaction 更灵活

LevelDB 的 compaction 策略相对简单。

RocksDB 支持更多 compaction 策略，例如：

- Level Compaction；
- Universal Compaction；
- FIFO Compaction。

Universal Compaction 在某些写多场景下可以降低写放大，但可能带来更高的读放大或空间放大。

所以 compaction 策略不是越强越好，而是要根据业务读写比例、空间预算和延迟要求做取舍。

### 2. 并发能力更强

RocksDB 支持更强的后台并发能力，包括：

- 多线程 flush；
- 多线程 compaction；
- 更细粒度的后台任务调度。

这对于 SSD 和多核机器更友好。

### 3. Bloom Filter 和 Block Cache 能力更丰富

Bloom Filter 可以快速判断一个 key 大概率不存在于某个 SSTable 中，从而减少无效读取。

Block Cache 则用于缓存 SSTable 中的数据块和索引块，减少磁盘访问。

LevelDB 也有相关能力，但 RocksDB 在配置项和优化空间上更丰富。

### 4. Column Families

RocksDB 支持 Column Families。

可以把它理解成同一个 RocksDB 实例里有多组相对独立的逻辑列族，不同 Column Family 可以有不同配置，例如：

- 不同的 compaction 策略；
- 不同的 block size；
- 不同的 bloom filter；
- 不同的 TTL 或 compaction filter。

这让一个 RocksDB 实例可以承载多类不同访问模式的数据。

### 5. Compaction Filters

Compaction Filter 允许在 compaction 过程中自定义数据清理逻辑。

比如：

- 删除过期数据；
- 清理不再需要的业务记录；
- 根据业务规则决定某些 key 是否继续保留。

这类逻辑如果放在正常读写路径中做，可能影响前台延迟；放到 compaction 中做，可以利用后台整理过程顺便完成。

### 6. Snapshot、Checkpoint 和 Backup

Snapshot 提供的是某个 sequence number 上的一致性读视图。

它主要用于：

- 一致性读取；
- 遍历过程中避免看到中途变化；
- 给上层提供稳定视图。

但是 Snapshot 不等同于完整备份。

如果要做备份，通常还需要 Checkpoint 或 BackupEngine 之类的机制，把当前版本依赖的 SSTable、Manifest 等文件组织成可恢复的数据集。

---

## 小结

LevelDB 的核心可以概括为：

1. 前台写入先追加 WAL，再写 memtable；
2. memtable 满了之后转成 immutable memtable；
3. immutable memtable 后台 flush 成 Level-0 SSTable；
4. Level-0 文件之间 key range 可以重叠；
5. Level-1 及以上层级通过 compaction 维持同层 key range 尽量不重叠；
6. compaction 负责合并文件、清理旧版本、回收空间；
7. 整个系统是在读放大、写放大、空间放大之间做权衡。

RocksDB 的改进主要集中在更灵活的 compaction、更强的并发、更丰富的配置能力，以及对生产场景更完整的功能支持。
