---
title: "MyBatis 打印 sql 日志 (Spring + MyBatis)"
date: 2016-03-26
tags: [Java, Spring, MyBatis, Log4j, Logging]
draft: true
---
## MyBatis打印日志的配置分为两部分：MyBatis的配置和Log4j的配置
* 首先MyBatis的配置（注：中文的文档里面没有这些）：http://mybatis.org/mybatis-3/logging.html
	* 在spring的sqlSessionFactory中配置mybatis的配置的位置
		* mybatis-config.xml这个配置文件可以扩展MyBatis的一些配置，而不用首先与spring的固有格式	
		* 在mybatis-config.xml里面配置好MyBatis日志的实现方式
			* MyBatis支持的日志实现有：SLF4J、Apache Commons Logging、Log4j 2、Log4j、JDK logging，但这里只展示log4j的配置

		
``` 
spring的配置

    <bean id="sqlSessionFactory" class="org.mybatis.spring.SqlSessionFactoryBean">
        ***
        <property name="configLocation" value="classpath:spring/mybatis-config.xml"/>
        ***
    </bean>
```

```
mybati-config.xml的配置

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE configuration
        PUBLIC "-//mybatis.org//DTD Config 3.0//EN"
        "http://mybatis.org/dtd/mybatis-3-config.dtd">

<configuration>
    <settings>
    	***
        <setting name="logImpl" value="LOG4J"/>
        ***
    </settings>
</configuration>
```
* Log4j的配置
	* https://logging.apache.org/log4j/1.2/manual.html
	* 按Log4j的文档，其配置主要有：Loggers、Appenders和Layouts
	* 其中Appenders和Layouts都可以copy别人的代码再对其进行修改来进行配置，下面是我的其中一个appender的配置，也是用于MyBatis的sql日志的配置。
		* 需要注意的配置有encoding，日志的编码
		* threshold，这个appender会记录的日志的level
			* 日志的level有：TRACE,DEBUG,INFO,WARN,ERROR and FATAL
		* layout配置，打印日志的格式

```
log4j的appender配置

<appender name="DEBUG-APPENDER" class="org.apache.log4j.DailyRollingFileAppender">
        <param name="file" value="/Users/emotion/logs/applog/debug.log"/>
        <param name="append" value="true"/>
        <param name="encoding" value="UTF-8"/>
        <param name="threshold" value="DEBUG"/>
        <layout class="org.apache.log4j.PatternLayout">
            <param name="ConversionPattern"
                   value="%d [%X{requestURIWithQueryString}]%n  SQL：  %-5p %c{2} - %m%n"/>
        </layout>
    </appender>
```

* 接着
	* logger的配置
	* 我们可以将logger看做一棵树，其中root节点是所有日志都会汇入<root>节点的appender中
	* 当我们定义了logger之后，以logger的name作为package或者class，在这个package之下的class或者这个class的日志会使用这个特别定制的appender
	* 这样我们就可以将我们需要分离出来的日志，单独做一个appender，避免和其它文件混合在一起而导致很难查找了。
	* 在logger中的name为package或者class
	* level就是记录的日志的等级
	* appender-ref则是这个日志流会流向的appender引用
	
```
<root>
        <level value="INFO"/>
        <appender-ref ref="PROJECT"/>
        <appender-ref ref="JmonitorAppender"/>
    </root>
```

```
log4j的logger配置

   <logger name="org.apache.ibatis" additivity="true">
        <level value="DEBUG"/>
        <appender-ref ref="DEBUG-APPENDER"/>
    </logger>
    <logger name="java.sql.Statement" additivity="true">
        <level value="DEBUG"/>
        <appender-ref ref="DEBUG-APPENDER"/>
    </logger>
    <logger name="java.sql" additivity="true">
        <level value="DEBUG"/>
        <appender-ref ref="DEBUG-APPENDER"/>
    </logger>
    <logger name="com.aliyun.tianchi.model" additivity="true">
        <level value="DEBUG"/>
        <appender-ref ref="DEBUG-APPENDER"/>
    </logger>
    <logger name="com.aliyun.tianchi.mapper" additivity="true">
        <level value="DEBUG"/>
        <appender-ref ref="DEBUG-APPENDER"/>
    </logger>
```

* 总结
	* 首先在MyBatis中定义logImpl，这样就可以让MyBatis的日志机制正常工作
	* 在log4j中配置好level为debug的appender和logger，这样就可以让应用的日志系统正常的记录MyBatis的日志到配置的文件里面了。
