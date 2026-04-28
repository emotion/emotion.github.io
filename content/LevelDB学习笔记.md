---
title: "LevelDB 学习笔记"
date: 2025-03-15
tags: [LevelDB, RocksDB, LSM, 存储引擎]
draft: false
---
## 整体理解
1. leveldb是一个基于LSM（Log Structre-Merge Tree）的存储引擎
2. 先写logfile
3. 然后记录到mutable的memtable
4. mutable的memtable到达阈值，转成immutable的memtable
5. immutable的memtable打到阈值后，写入level0
6. level0到达阈值后，和level1合并到level1



## RocksDB改进点
1. compaction改进
	1. compact时机提前，如果写放大变得太高，也会触发compact
	2. 并发compact
2. 读写放大
	1. universal compaction减少写放大
	2. 更好的compaction也会减少读放大
	3. bloom filters可以不读内容判断key是否存在，减少读放大
3. Column Families
	1. 不同的column簇可以有不同的配置，可以更灵活
4. Compaction Filters
	1. 自定义compact策略，比如清除部分数据
5. Snapshots
	1. 备份的时候，避免stop the world或者正在变更数据的影响
	2. 通过版本号和当前所有的数据块可以实现