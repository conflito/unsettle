# UNSETTLE (aUtomatic uNit teSt gEneraTion for semanTic confLict dEtection)

UNSETTLE is a framework that automatically detects semantic conflicts in version
control systems (e.g., git) of Java programs.  It first identifies common causes
of semantic conflicts in merge commits and then generates unit test cases that
reveal the conflicts.

UNSETTLE is mainly composed by two modules:

1. [Changes-Matcher](https://github.com/conflito/changes-matcher) which is
responsible for identifying whether any common cause of semantic conflicts
(e.g., parallel modifications to the same method) has occurred in a given merge commit.
2. [Test Generator](https://github.com/conflito/evosuite/tree/trigger-semantic-conflict)
which is responsible for generating a conflict-revealing test case.

Given the following merge scenario as an example:

![Merge scenario](.fig/merge-scenario.png)

[Changes-Matcher](https://github.com/conflito/changes-matcher) starts by
computing the differences between the base version of a merge commit and each
variant (i.e., branch).  Then, it compares these changes to a set of change
patterns that capture potential causes for semantic conflicts.  If the changes
correspond to an instance of a pattern,
[Changes-Matcher](https://github.com/conflito/changes-matcher) has successfully
identified a semantic conflict in the merge commit.

Once the conflict has been identified, the test generation phase takes place.
The [test generator](https://github.com/conflito/evosuite/tree/trigger-semantic-conflict),
built on top of the [EvoSuite](https://github.com/EvoSuite/evosuite) tool, is
guided by the information about the changes between the base version and its
variants to find a test that is able to trigger the conflict.  (One can find in
[here](https://github.com/conflito/evosuite/compare/4f0aa143210ce4e71ae2b3543231b4707d461476...cee583f23076b4bea032548c080c065ff54fbef1)
the exact set of changes we made to the [EvoSuite](https://github.com/EvoSuite/evosuite)
tool to support the generation of semantic conflict-revealing test.)

## Requirements

- Java 1.8
- [Apache Maven](https://maven.apache.org) 3.6.1 or later.

For convenience, the [`tools/get-tools.sh`](`tools/get-tools.sh`) script
automatically downloads and builds all requirements and UNSETTLE's modules.

To ease the usage of the [Changes-Matcher](https://github.com/conflito/changes-matcher) tool
and the [Test Generator](https://github.com/conflito/evosuite/tree/trigger-semantic-conflict)
in the following example, export the following environment variables

```bash
export CHANGES_MATCHER_JAR="$(pwd)/target/changes-matcher.jar"
export TEST_GENERATOR_JAR="$(pwd)/tools/evosuite.jar"
```

Tip: before going ahead, verify whether the environment variables are correctly
initialized and pointing to existing files.

```bash
[ -s "$CHANGES_MATCHER_JAR" ] || echo "$CHANGES_MATCHER_JAR does not exist or it is empty!"
[ -s "$TEST_GENERATOR_JAR" ]  || echo "$TEST_GENERATOR_JAR does not exist or it is empty!"
```

## Using UNSETTLE

In a common merge scenario, as the one in the figure above, four versions of the
program under test are required to run UNSETTLE:
- the base version
- variant 1 version (usually called 'left' in the literature)
- variant 2 version (usually called 'right' in the literature)
- merge version

As described in the following table, for the base version UNSETTLE only requires
the source code, for the merge version it only requires the compiled classes,
and for both variants it requires the source code and the compiled classes.

| Version   | Source code | Compiled classes |
|:----------|:------------|:----------------:|
| base      | YES         | NO               |
| variant 1 | YES         | YES              |
| variant 2 | YES         | YES              |
| merge     | NO          | YES              |

As a usage example, let us consider the project https://github.com/netty/netty
and its merge commit [193acdb36cd3da9bfc62dd69c4208dff3f0a2b1b](https://github.com/netty/netty/tree/193acdb36cd3da9bfc62dd69c4208dff3f0a2b1b).
In detail,

- Repository URL: [https://github.com/netty/netty.git](https://github.com/netty/netty.git)
- Base commit: [2fc18a00f6ac61a365b73dd498dd2e38f1efa823](https://github.com/netty/netty/commit/2fc18a00f6ac61a365b73dd498dd2e38f1efa823)
- Variant 1 commit: [b3b096834cafc7f348583786d71567e9fa001b55](https://github.com/netty/netty/commit/b3b096834cafc7f348583786d71567e9fa001b55)
- Variant 2 commit: [c2417c253c48bac942decfe923743d2b09d63a5f](https://github.com/netty/netty/commit/c2417c253c48bac942decfe923743d2b09d63a5f)
- Merge commit: [193acdb36cd3da9bfc62dd69c4208dff3f0a2b1b](https://github.com/netty/netty/commit/193acdb36cd3da9bfc62dd69c4208dff3f0a2b1b)

Note: the base commit can automatically be extracted from project's git
repository, e.g.,

```bash
git merge-base --octopus b3b096834cafc7f348583786d71567e9fa001b55 c2417c253c48bac942decfe923743d2b09d63a5f
```

### Setup

0. Pre step

```bash
mkdir /tmp/unsettle-motivational-example
cd /tmp/unsettle-motivational-example
```

1. Clone project's repository

```bash
git clone --bare https://github.com/netty/netty.git netty-repository.git
```

2. Get base, variant 1, variant 2, and merge versions

```bash
# Base
git clone netty-repository.git base
(cd base; git checkout 2fc18a00f6ac61a365b73dd498dd2e38f1efa823)

# Variant 1
git clone netty-repository.git variant-1
(cd variant-1; git checkout b3b096834cafc7f348583786d71567e9fa001b55)

# Variant 2
git clone netty-repository.git variant-2
(cd variant-2; git checkout c2417c253c48bac942decfe923743d2b09d63a5f)

# Merge
git clone netty-repository.git merge
(cd merge; git checkout 193acdb36cd3da9bfc62dd69c4208dff3f0a2b1b)
```

3. Build variant 1, variant 2, and merge versions

```bash
# Variant 1
(cd variant-1; mvn clean compile -Dmaven.repo.local="$(pwd)/.m2")

# Variant 2
(cd variant-2; mvn clean compile -Dmaven.repo.local="$(pwd)/.m2")

# Merge
(cd merge; mvn clean compile -Dmaven.repo.local="$(pwd)/.m2")
```

4. Collect variant 1's, variant 2's, and merge's dependencies

```bash
# Variant 1
(cd variant-1; mvn dependency:copy-dependencies -Dmaven.repo.local="$(pwd)/.m2" -DoutputDirectory="$(pwd)/.deps")

# Variant 2
(cd variant-2; mvn dependency:copy-dependencies -Dmaven.repo.local="$(pwd)/.m2" -DoutputDirectory="$(pwd)/.deps")

# Merge
(cd merge; mvn dependency:copy-dependencies -Dmaven.repo.local="$(pwd)/.m2" -DoutputDirectory="$(pwd)/.deps")
```

5. Collect variant 1's, variant 2's, and merge's classpath

```bash
# Variant 1
variant_1_classpath=$(cd variant-1; echo $(pwd)/target/classes:$(find .deps -type f -name "*.jar" | grep -v "junit" | grep -v "hamcrest" | sed "s|^|$(pwd)/|g" | tr '\n' ':'))

# Variant 2
variant_2_classpath=$(cd variant-2; echo $(pwd)/target/classes:$(find .deps -type f -name "*.jar" | grep -v "junit" | grep -v "hamcrest" | sed "s|^|$(pwd)/|g" | tr '\n' ':'))

# Merge
merge_classpath=$(cd merge; echo $(pwd)/target/classes:$(find .deps -type f -name "*.jar" | grep -v "junit" | grep -v "hamcrest" | sed "s|^|$(pwd)/|g" | tr '\n' ':'))
```

6. Collect the set of `.java` files involved in the merge commit

```bash
# Get set of files involved in the merge commit
modified_files=$(cd merge; git diff --name-only HEAD^1 src/main/java)

# Path to the files involved in the merge commit under base/
base_modified_files=$(echo "$modified_files" | sed "s|^|$(pwd)/base/|g" | tr '\n' ';')

# Path to the files involved in the merge commit under variant-1/
variant_1_modified_files=$(echo "$modified_files" | sed "s|^|$(pwd)/variant-1/|g" | tr '\n' ';')

# Path to the files involved in the merge commit under variant-2/
variant_2_modified_files=$(echo "$modified_files" | sed "s|^|$(pwd)/variant-2/|g" | tr '\n' ';')
```

### Semantic Conflict Detection

[Changes-Matcher](https://github.com/conflito/changes-matcher) relies on a
configuration file that allows one for some customizable options.  For the
project example the configuration file (e.g., `netty-193acdb-configuration.txt`)
can be configured as

```
# Absolute path to the source directory of the base version
base.src.dir=/tmp/unsettle-motivational-example/base/src/main/java

# Absolute path to the source directory of the first variant version
var1.src.dir=/tmp/unsettle-motivational-example/variant-1/src/main/java

# Absolute path to the source directory of the second variant version
var2.src.dir=/tmp/unsettle-motivational-example/variant-2/src/main/java

# Absolute classpath of the first variant version
var1.cp.dir= ... i.e., the content of the $variant_1_classpath variable

# Absolute classpath of the second variant version
var2.cp.dir= ... i.e., the content of the $variant_2_classpath variable

# Absolute classpath of the merge version
merge.cp.dir= ... i.e., the content of the $merge_classpath variable
```

Once the configuration file is in place, the
[Changes-Matcher](https://github.com/conflito/changes-matcher) tool can be
executed as

```bash
java -jar "$CHANGES_MATCHER_JAR" \
  --base <path>[;<path>] \
  --variant1 <path>[;<path>] \
  --variant2 <path>[;<path>] \
  --config <path>
```

where

- `--base` are the absolute paths to the base version of the files modified in the merge version, use `;` to define more than one path
- `--variant1` are the absolute paths to the first variant version of the files modified in the merge version, use `;` to define more than one path
- `--variant2` are the absolute paths to the second version of the files modified in the merge version, use `;` to define more than one path
- `--config` is the absolute path to the configuration file

Upon a successful execution, this command writes to the stdout the (variable,
value) pairings and the testing goals (target class and methods to cover) for
the test generation step.

Note: By default, [Changes-Matcher](https://github.com/conflito/changes-matcher)
attempts to match any of the known patterns.  However, the `--conflict_name <pattern name>`
option could be used to search for a particular change pattern.  One can also
use the ``--list_patterns`` option to list the accepted names.

For the running example, one could run the command above as

```bash
java -jar "$CHANGES_MATCHER_JAR" \
  --base "$base_modified_files" \
  --variant1 "$variant_1_modified_files" \
  --variant2 "$variant_2_modified_files" \
  --config netty-193acdb-configuration.txt \
  --output_file netty-193acdb-matches.txt
```

which write to `netty-193acdb-matches.txt` the following content

```
[
  {
    "conflictName" : "Parallel Changes",
    "variableAssignments" : [
      {
        "variable" : 0,
        "value" : "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder"
      },
      {
        "variable" : 1,
        "value" : "decode(org.jboss.netty.channel.ChannelHandlerContext, org.jboss.netty.channel.Channel, org.jboss.netty.buffer.ChannelBuffer)"
      }
    ],
    "testingGoal" : {
      "targetClass" : "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder",
      "coverMethods" : [
        "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.decode(Lorg/jboss/netty/channel/ChannelHandlerContext;Lorg/jboss/netty/channel/Channel;Lorg/jboss/netty/buffer/ChannelBuffer;)Ljava/lang/Object;"
      ],
      "coverMethodsLine" : "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.decode(Lorg/jboss/netty/channel/ChannelHandlerContext;Lorg/jboss/netty/channel/Channel;Lorg/jboss/netty/buffer/ChannelBuffer;)Ljava/lang/Object;"
    }
  },
  {
    "conflictName" : "Change Method 3",
    "variableAssignments" : [
      {
        "variable" : 0,
        "value" : "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder"
      },
      {
        "variable" : 1,
        "value" : "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder"
      },
      {
        "variable" : 2,
        "value" : "decode(org.jboss.netty.channel.ChannelHandlerContext, org.jboss.netty.channel.Channel, org.jboss.netty.buffer.ChannelBuffer)"
      },
      {
        "variable" : 3,
        "value" : "failIfNecessary(org.jboss.netty.channel.ChannelHandlerContext)"
      }
    ],
    "testingGoal" : {
      "targetClass" : "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder",
      "coverMethods" : [
        "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.decode(Lorg/jboss/netty/channel/ChannelHandlerContext;Lorg/jboss/netty/channel/Channel;Lorg/jboss/netty/buffer/ChannelBuffer;)Ljava/lang/Object;",
        "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.failIfNecessary(Lorg/jboss/netty/channel/ChannelHandlerContext;)V"
      ],
      "coverMethodsLine" : "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.decode(Lorg/jboss/netty/channel/ChannelHandlerContext;Lorg/jboss/netty/channel/Channel;Lorg/jboss/netty/buffer/ChannelBuffer;)Ljava/lang/Object;:org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.failIfNecessary(Lorg/jboss/netty/channel/ChannelHandlerContext;)V"
    }
  }
]
```

Each `JSON` object in the returned list above informs the developer which
patterns (i.e., semantic conflict) matched, and for each pattern, which class (``targetClass``) and
methods (``coverMethods``) should be tested to trigger/reveal the pattern.  For
the running example, two patterns patched: "Parallel Changes" and "Change Method 3".

- To trigger the "Parallel Changes" pattern, a test generator would have
to generate tests for the class `org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder`
and the method `org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.decode(Lorg/jboss/netty/channel/ChannelHandlerContext;Lorg/jboss/netty/channel/Channel;Lorg/jboss/netty/buffer/ChannelBuffer;)Ljava/lang/Object;`.

- To trigger the "Change Method 3" pattern, a test generator would have
to generate tests for the class `org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder`
and the methods `org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.decode(Lorg/jboss/netty/channel/ChannelHandlerContext;Lorg/jboss/netty/channel/Channel;Lorg/jboss/netty/buffer/ChannelBuffer;)Ljava/lang/Object;` and `org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.failIfNecessary(Lorg/jboss/netty/channel/ChannelHandlerContext;)V`.

(Note: for simplicity, the ``coverMethodsLine`` represents the combined string
of `coverMethods` to ease the initialization of the [test generator's](https://github.com/conflito/evosuite/tree/trigger-semantic-conflict)'s
option ``-Dcover_methods``.)

### Semantic Conflict Revealing

Given [Changes-Matcher's](https://github.com/conflito/changes-matcher) output,
one can now attempt to generate a unit test case that reveals the identified
conflict.  To achieve that, execute the following command

```bash
java -jar "$TEST_GENERATOR_JAR" \
  -projectCP <merge classpath> \
  -class <name> \
  -Dcover_methods=<names> \
  -Dregressioncp=<variant-1 classpath> \
  -Dsecond_regressioncp=<variant-2 classpath> \
  -criterion methodcall \
  -Dtest_factory=multi_test \
  -Dassertion_strategy=specific \
  -Dreplace_calls=false
```

where

- `projectCP` is the classpath of the merge version as `<path[:path]>` (note: on Windows, `:` is represented as `;`)
- `-class` is the qualified name of the class under test. This is outputted by the [Changes-Matcher](https://github.com/conflito/changes-matcher)
- `-Dcover_methods=` are the qualified names of the methods the generated test must cover specified as `classQualifiedName.methodDescriptor;classQualifiedName.methodDescriptor;(...)`. The first method is the one that is allowed to appear directly in the test. These are the testing goals outputted by the [Changes-Matcher](https://github.com/conflito/changes-matcher).
- `-Dregressioncp=` is the classpath of the first variant version as `<path[:path]>` (note: on Windows, `:` is represented as `;`)
- `-Dsecond_regressioncp=` is the classpath of the second variant version as `<path[:path]>` (note: on Windows, `:` is represented as `;`)

Note: An additional property `-Ddistance_threshold=]0..1]` is also available to
set the threshold used by the
[test generator](https://github.com/conflito/evosuite/tree/trigger-semantic-conflict)
to consider objects sufficiently different.

For the running example, and to reveal the parallel change conflict, one could
run the command above as

```bash
java -jar "$TEST_GENERATOR_JAR" \
  -seed 0 \
  -projectCP "$merge_classpath" \
  -class "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder" \
  -Dcover_methods="org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.decode(Lorg/jboss/netty/channel/ChannelHandlerContext;Lorg/jboss/netty/channel/Channel;Lorg/jboss/netty/buffer/ChannelBuffer;)Ljava/lang/Object;" \
  -Dregressioncp="$variant_1_classpath" \
  -Dsecond_regressioncp="$variant_2_classpath" \
  -criterion methodcall \
  -Dtest_factory=multi_test \
  -Dassertion_strategy=specific \
  -Dreplace_calls=true \
  -Ddistance_threshold=0.05 \
  -Dsearch_budget=60
```

which, by default, writes to the `evosuite-tests` directory the following test
class that reveals the semantic conflict

```java
package org.jboss.netty.handler.codec.frame;

import org.junit.Test;
import static org.junit.Assert.*;
import static org.evosuite.shaded.org.mockito.Mockito.*;
import java.nio.ByteBuffer;
import org.evosuite.AllFieldsCalculator;
import org.evosuite.runtime.EvoRunner;
import org.evosuite.runtime.EvoRunnerParameters;
import org.evosuite.runtime.ViolatedAssumptionAnswer;
import org.jboss.netty.buffer.ByteBufferBackedChannelBuffer;
import org.jboss.netty.buffer.ChannelBuffer;
import org.jboss.netty.buffer.DuplicatedChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder;
import org.junit.runner.RunWith;
import org.evosuite.AllFieldsCalculator;

@RunWith(EvoRunner.class) @EvoRunnerParameters(mockJVMNonDeterminism = true, useVFS = true, useVNET = true, resetStaticState = true, separateClassLoader = true, useJEE = true) 
public class LengthFieldBasedFrameDecoder_ESTest extends LengthFieldBasedFrameDecoder_ESTest_scaffolding {

  @Test(timeout = 4000)
  public void test0()  throws Throwable  {
      LengthFieldBasedFrameDecoder lengthFieldBasedFrameDecoder0 = new LengthFieldBasedFrameDecoder(2791, 0, 3);
      ChannelHandlerContext channelHandlerContext0 = mock(ChannelHandlerContext.class, new ViolatedAssumptionAnswer());
      Channel channel0 = mock(Channel.class, new ViolatedAssumptionAnswer());
      byte[] byteArray0 = new byte[9];
      byteArray0[0] = (byte) (-119);
      byteArray0[1] = (byte)0;
      byteArray0[2] = (byte)0;
      byteArray0[3] = (byte) (-84);
      byteArray0[4] = (byte)107;
      byteArray0[5] = (byte)3;
      byteArray0[6] = (byte) (-33);
      byteArray0[7] = (byte) (-47);
      byteArray0[8] = (byte) (-1);
      ByteBuffer byteBuffer0 = ByteBuffer.wrap(byteArray0);
      ByteBufferBackedChannelBuffer byteBufferBackedChannelBuffer0 = new ByteBufferBackedChannelBuffer(byteBuffer0);
      ChannelBuffer channelBuffer0 = byteBufferBackedChannelBuffer0.duplicate();
      DuplicatedChannelBuffer duplicatedChannelBuffer0 = new DuplicatedChannelBuffer(channelBuffer0);
      Object object0 = lengthFieldBasedFrameDecoder0.decode(channelHandlerContext0, channel0, duplicatedChannelBuffer0);
      assertNull(object0);
      
      ChannelHandlerContext channelHandlerContext1 = mock(ChannelHandlerContext.class, new ViolatedAssumptionAnswer());
      Channel channel1 = mock(Channel.class, new ViolatedAssumptionAnswer());
      Object object1 = lengthFieldBasedFrameDecoder0.decode(channelHandlerContext1, channel1, byteBufferBackedChannelBuffer0);
      assertNull(object1);
      
      long long0 = AllFieldsCalculator.allFieldsMethod(lengthFieldBasedFrameDecoder0);
      assertEquals((-2375578718444642195L), long0);
      
      AllFieldsCalculator.allFieldsMethod(channelHandlerContext0);
      AllFieldsCalculator.allFieldsMethod(channel0);
      AllFieldsCalculator.allFieldsMethod(byteBuffer0);
      AllFieldsCalculator.allFieldsMethod(byteBufferBackedChannelBuffer0);
      AllFieldsCalculator.allFieldsMethod(channelBuffer0);
      AllFieldsCalculator.allFieldsMethod(duplicatedChannelBuffer0);
      long long1 = AllFieldsCalculator.allFieldsMethod(object0);
      assertEquals(0L, long1);
      
      AllFieldsCalculator.allFieldsMethod(channelHandlerContext1);
      AllFieldsCalculator.allFieldsMethod(channel1);
      long long2 = AllFieldsCalculator.allFieldsMethod(object1);
      assertEquals(0L, long2);
  }
}

```

and its correspondent scaffolding class

```java
package org.jboss.netty.handler.codec.frame;

import org.evosuite.runtime.annotation.EvoSuiteClassExclude;
import org.junit.BeforeClass;
import org.junit.Before;
import org.junit.After;
import org.junit.AfterClass;
import org.evosuite.runtime.sandbox.Sandbox;
import org.evosuite.runtime.sandbox.Sandbox.SandboxMode;

import static org.evosuite.shaded.org.mockito.Mockito.*;
@EvoSuiteClassExclude
public class LengthFieldBasedFrameDecoder_ESTest_scaffolding {

  @org.junit.Rule 
  public org.evosuite.runtime.vnet.NonFunctionalRequirementRule nfr = new org.evosuite.runtime.vnet.NonFunctionalRequirementRule();

  private static final java.util.Properties defaultProperties = (java.util.Properties) java.lang.System.getProperties().clone(); 

  private org.evosuite.runtime.thread.ThreadStopper threadStopper =  new org.evosuite.runtime.thread.ThreadStopper (org.evosuite.runtime.thread.KillSwitchHandler.getInstance(), 3000);


  @BeforeClass 
  public static void initEvoSuiteFramework() { 
    org.evosuite.runtime.RuntimeSettings.className = "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder"; 
    org.evosuite.runtime.GuiSupport.initialize(); 
    org.evosuite.runtime.RuntimeSettings.maxNumberOfThreads = 100; 
    org.evosuite.runtime.RuntimeSettings.maxNumberOfIterationsPerLoop = 10000; 
    org.evosuite.runtime.RuntimeSettings.mockSystemIn = true; 
    org.evosuite.runtime.RuntimeSettings.sandboxMode = org.evosuite.runtime.sandbox.Sandbox.SandboxMode.RECOMMENDED; 
    org.evosuite.runtime.sandbox.Sandbox.initializeSecurityManagerForSUT(); 
    org.evosuite.runtime.classhandling.JDKClassResetter.init();
    setSystemProperties();
    initializeClasses();
    org.evosuite.runtime.Runtime.getInstance().resetRuntime(); 
    try { initMocksToAvoidTimeoutsInTheTests(); } catch(ClassNotFoundException e) {} 
  } 

  @AfterClass 
  public static void clearEvoSuiteFramework(){ 
    Sandbox.resetDefaultSecurityManager(); 
    java.lang.System.setProperties((java.util.Properties) defaultProperties.clone()); 
  } 

  @Before 
  public void initTestCase(){ 
    threadStopper.storeCurrentThreads();
    threadStopper.startRecordingTime();
    org.evosuite.runtime.jvm.ShutdownHookHandler.getInstance().initHandler(); 
    org.evosuite.runtime.sandbox.Sandbox.goingToExecuteSUTCode(); 
    setSystemProperties(); 
    org.evosuite.runtime.GuiSupport.setHeadless(); 
    org.evosuite.runtime.Runtime.getInstance().resetRuntime(); 
    org.evosuite.runtime.agent.InstrumentingAgent.activate(); 
  } 

  @After 
  public void doneWithTestCase(){ 
    threadStopper.killAndJoinClientThreads();
    org.evosuite.runtime.jvm.ShutdownHookHandler.getInstance().safeExecuteAddedHooks(); 
    org.evosuite.runtime.classhandling.JDKClassResetter.reset(); 
    resetClasses(); 
    org.evosuite.runtime.sandbox.Sandbox.doneWithExecutingSUTCode(); 
    org.evosuite.runtime.agent.InstrumentingAgent.deactivate(); 
    org.evosuite.runtime.GuiSupport.restoreHeadlessMode(); 
  } 

  public static void setSystemProperties() {
 
    java.lang.System.setProperties((java.util.Properties) defaultProperties.clone()); 
    java.lang.System.setProperty("file.encoding", "UTF-8"); 
    java.lang.System.setProperty("java.awt.headless", "true"); 
    java.lang.System.setProperty("java.io.tmpdir", "/var/folders/p1/2z34ggcn6xnc53xl4hlfq8200000gn/T/"); 
    java.lang.System.setProperty("user.country", "PT"); 
    java.lang.System.setProperty("user.dir", "/private/tmp/unsettle-motivational-example"); 
    java.lang.System.setProperty("user.home", "/Users/foo"); 
    java.lang.System.setProperty("user.language", "en"); 
    java.lang.System.setProperty("user.name", "foo"); 
    java.lang.System.setProperty("user.timezone", "Europe/Lisbon"); 
  }

  private static void initializeClasses() {
    org.evosuite.runtime.classhandling.ClassStateSupport.initializeClasses(LengthFieldBasedFrameDecoder_ESTest_scaffolding.class.getClassLoader() ,
      "org.jboss.netty.buffer.ChannelBufferIndexFinder$9",
      "org.jboss.netty.buffer.ChannelBufferIndexFinder$8",
      "org.jboss.netty.buffer.ChannelBufferIndexFinder$7",
      "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder",
      "org.jboss.netty.buffer.ChannelBufferIndexFinder$6",
      "org.jboss.netty.channel.ChannelFutureProgressListener",
      "org.jboss.netty.buffer.ChannelBufferFactory",
      "org.jboss.netty.channel.ChildChannelStateEvent",
      "org.jboss.netty.logging.JdkLoggerFactory",
      "org.jboss.netty.buffer.ChannelBuffer",
      "org.jboss.netty.buffer.ChannelBufferIndexFinder$1",
      "org.jboss.netty.channel.CompleteChannelFuture",
      "org.jboss.netty.handler.codec.frame.CorruptedFrameException",
      "org.jboss.netty.buffer.AbstractChannelBuffer",
      "org.jboss.netty.buffer.ChannelBufferIndexFinder$5",
      "org.jboss.netty.buffer.DuplicatedChannelBuffer",
      "org.jboss.netty.buffer.ChannelBufferIndexFinder$4",
      "org.jboss.netty.buffer.ChannelBufferIndexFinder$3",
      "org.jboss.netty.buffer.ChannelBufferIndexFinder$2",
      "org.jboss.netty.channel.ChannelPipeline",
      "org.jboss.netty.buffer.BigEndianHeapChannelBuffer",
      "org.jboss.netty.channel.ChannelFutureListener",
      "org.jboss.netty.channel.ChannelState",
      "org.jboss.netty.logging.InternalLoggerFactory",
      "org.jboss.netty.channel.ExceptionEvent",
      "org.jboss.netty.logging.InternalLoggerFactory$1",
      "org.jboss.netty.util.internal.SystemPropertyUtil",
      "org.jboss.netty.util.internal.DeadLockProofWorker",
      "org.jboss.netty.channel.ChannelException",
      "org.jboss.netty.channel.SucceededChannelFuture",
      "org.jboss.netty.channel.ChannelFutureListener$2",
      "org.jboss.netty.channel.SimpleChannelUpstreamHandler",
      "org.jboss.netty.buffer.ByteBufferBackedChannelBuffer",
      "org.jboss.netty.buffer.ChannelBufferIndexFinder$10",
      "org.jboss.netty.channel.ChannelConfig",
      "org.jboss.netty.channel.ChannelPipelineFactory",
      "org.jboss.netty.channel.ChannelFutureListener$1",
      "org.jboss.netty.logging.AbstractInternalLogger",
      "org.jboss.netty.channel.ChannelEvent",
      "org.jboss.netty.util.DebugUtil",
      "org.jboss.netty.util.internal.StackTraceSimplifier",
      "org.jboss.netty.buffer.LittleEndianHeapChannelBuffer",
      "org.jboss.netty.channel.DownstreamMessageEvent",
      "org.jboss.netty.logging.InternalLogger",
      "org.jboss.netty.util.ExternalResourceReleasable",
      "org.jboss.netty.buffer.ChannelBuffers",
      "org.jboss.netty.buffer.ChannelBufferIndexFinder",
      "org.jboss.netty.channel.ChannelHandlerContext",
      "org.jboss.netty.buffer.WrappedChannelBuffer",
      "org.jboss.netty.channel.ChannelFuture",
      "org.jboss.netty.channel.ChannelUpstreamHandler",
      "org.jboss.netty.channel.ChannelHandler",
      "org.jboss.netty.logging.InternalLogLevel",
      "org.jboss.netty.channel.ChannelSink",
      "org.jboss.netty.channel.Channel",
      "org.jboss.netty.handler.codec.frame.TooLongFrameException",
      "org.jboss.netty.channel.ChannelPipelineException",
      "org.jboss.netty.logging.JdkLogger",
      "org.jboss.netty.channel.MessageEvent",
      "org.jboss.netty.channel.WriteCompletionEvent",
      "org.jboss.netty.handler.codec.frame.FrameDecoder",
      "org.jboss.netty.channel.ChannelStateEvent",
      "org.jboss.netty.buffer.HeapChannelBuffer",
      "org.jboss.netty.channel.DefaultChannelFuture",
      "org.jboss.netty.channel.ChannelFactory"
    );
  } 
  private static void initMocksToAvoidTimeoutsInTheTests() throws ClassNotFoundException { 
    mock(Class.forName("org.jboss.netty.channel.Channel", false, LengthFieldBasedFrameDecoder_ESTest_scaffolding.class.getClassLoader()));
    mock(Class.forName("org.jboss.netty.channel.ChannelHandlerContext", false, LengthFieldBasedFrameDecoder_ESTest_scaffolding.class.getClassLoader()));
  }

  private static void resetClasses() {
    org.evosuite.runtime.classhandling.ClassResetter.getInstance().setClassLoader(LengthFieldBasedFrameDecoder_ESTest_scaffolding.class.getClassLoader()); 

    org.evosuite.runtime.classhandling.ClassStateSupport.resetClasses(
      "org.jboss.netty.logging.JdkLoggerFactory",
      "org.jboss.netty.util.DebugUtil",
      "org.jboss.netty.util.internal.SystemPropertyUtil",
      "org.jboss.netty.util.internal.StackTraceSimplifier",
      "org.jboss.netty.logging.InternalLoggerFactory",
      "org.jboss.netty.logging.AbstractInternalLogger",
      "org.jboss.netty.logging.JdkLogger",
      "org.jboss.netty.logging.InternalLoggerFactory$1",
      "org.jboss.netty.channel.SimpleChannelUpstreamHandler",
      "org.jboss.netty.handler.codec.frame.FrameDecoder",
      "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder",
      "org.jboss.netty.buffer.AbstractChannelBuffer",
      "org.jboss.netty.buffer.HeapChannelBuffer",
      "org.jboss.netty.buffer.LittleEndianHeapChannelBuffer",
      "org.jboss.netty.channel.DefaultChannelFuture",
      "org.jboss.netty.util.internal.DeadLockProofWorker",
      "org.jboss.netty.buffer.ByteBufferBackedChannelBuffer",
      "org.jboss.netty.buffer.DuplicatedChannelBuffer",
      "org.jboss.netty.channel.CompleteChannelFuture",
      "org.jboss.netty.channel.SucceededChannelFuture",
      "org.jboss.netty.channel.DownstreamMessageEvent",
      "org.jboss.netty.buffer.BigEndianHeapChannelBuffer",
      "org.jboss.netty.buffer.ChannelBuffers"
    );
  }
}
```

To verify whether the generated test case does indeed reveal the conflict, in
this particular example an emergent behavior (i.e., when the generated test
compiles and passes in the merge version, and either fails on both variants or
on a least one version) executed the following procedure

1. Compile and run the generated test on the merge version (which should compile
and pass)

```bash
(cd evosuite-tests; find . -type f -name "*.class" -exec rm {} \;; javac -cp "$merge_classpath:$TEST_GENERATOR_JAR" org/jboss/netty/handler/codec/frame/LengthFieldBasedFrameDecoder_ESTest.java)
(cd evosuite-tests; java -cp ".:$merge_classpath:$TEST_GENERATOR_JAR" org.junit.runner.JUnitCore org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder_ESTest)
```

2. Compile and run the generated test on the variants 1 and 2 (which should compile
and fail on both versions, and therefore reveal the semantic conflict, i.e.,
**emergent behaviour**).

```bash
(cd evosuite-tests; find . -type f -name "*.class" -exec rm {} \;; javac -cp "$variant_1_classpath:$TEST_GENERATOR_JAR" org/jboss/netty/handler/codec/frame/LengthFieldBasedFrameDecoder_ESTest.java)
(cd evosuite-tests; java -cp ".:$variant_1_classpath:$TEST_GENERATOR_JAR" org.junit.runner.JUnitCore org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder_ESTest)
```

```
There was 1 failure:
1) test0(org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder_ESTest)
java.lang.AssertionError: expected:<-2375578718444642195> but was:<-339368388349234776>
	at org.junit.Assert.fail(Assert.java:88)
	at org.junit.Assert.failNotEquals(Assert.java:834)
	at org.junit.Assert.assertEquals(Assert.java:645)
	at org.junit.Assert.assertEquals(Assert.java:631)
	at org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder_ESTest.test0(LengthFieldBasedFrameDecoder_ESTest.java:56)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:498)
	at org.junit.runners.model.FrameworkMethod$1.runReflectiveCall(FrameworkMethod.java:50)
	at org.junit.internal.runners.model.ReflectiveCallable.run(ReflectiveCallable.java:12)
	at org.junit.runners.model.FrameworkMethod.invokeExplosively(FrameworkMethod.java:47)
	at org.junit.internal.runners.statements.InvokeMethod.evaluate(InvokeMethod.java:17)
	at org.junit.internal.runners.statements.FailOnTimeout$CallableStatement.call(FailOnTimeout.java:298)
	at org.junit.internal.runners.statements.FailOnTimeout$CallableStatement.call(FailOnTimeout.java:292)
	at java.util.concurrent.FutureTask.run(FutureTask.java:266)
	at java.lang.Thread.run(Thread.java:748)
```

```bash
(cd evosuite-tests; find . -type f -name "*.class" -exec rm {} \;; javac -cp "$variant_2_classpath:$TEST_GENERATOR_JAR" org/jboss/netty/handler/codec/frame/LengthFieldBasedFrameDecoder_ESTest.java)
(cd evosuite-tests; java -cp ".:$variant_2_classpath:$TEST_GENERATOR_JAR" org.junit.runner.JUnitCore org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder_ESTest)
```

```
There was 1 failure:
1) test0(org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder_ESTest)
java.lang.AssertionError: expected:<-2375578718444642195> but was:<-339368387918331144>
	at org.junit.Assert.fail(Assert.java:88)
	at org.junit.Assert.failNotEquals(Assert.java:834)
	at org.junit.Assert.assertEquals(Assert.java:645)
	at org.junit.Assert.assertEquals(Assert.java:631)
	at org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder_ESTest.test0(LengthFieldBasedFrameDecoder_ESTest.java:56)
	at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
	at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
	at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
	at java.lang.reflect.Method.invoke(Method.java:498)
	at org.junit.runners.model.FrameworkMethod$1.runReflectiveCall(FrameworkMethod.java:50)
	at org.junit.internal.runners.model.ReflectiveCallable.run(ReflectiveCallable.java:12)
	at org.junit.runners.model.FrameworkMethod.invokeExplosively(FrameworkMethod.java:47)
	at org.junit.internal.runners.statements.InvokeMethod.evaluate(InvokeMethod.java:17)
	at org.junit.internal.runners.statements.FailOnTimeout$CallableStatement.call(FailOnTimeout.java:298)
	at org.junit.internal.runners.statements.FailOnTimeout$CallableStatement.call(FailOnTimeout.java:292)
	at java.util.concurrent.FutureTask.run(FutureTask.java:266)
	at java.lang.Thread.run(Thread.java:748)
```
