# UNSETTLE (aUtomatic uNit teSt gEneraTion for semanTic confLict dEtection)

UNSETTLE is a framework that automatically detects semantic conflicts in version
control systems (e.g., git) of Java programs.  It first identifies common causes
of semantic conflicts in merge commits and then generates unit test cases that
reveal the conflicts.

UNSETTLE is mainly composed by two modules:

1. [Changes-Matcher](https://github.com/conflito/changes-matcher) which is
responsible for identifying whether any common cause of semantic conflicts
(e.g., TODO) has occurred in a given merge commit.
2. [Test Generator](https://github.com/conflito/evosuite/tree/trigger-semantic-conflict-with-latest-evosuiter-version)
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
The [test generator](https://github.com/conflito/evosuite/tree/trigger-semantic-conflict-with-latest-evosuiter-version),
built on top of the [EvoSuite](https://github.com/EvoSuite/evosuite) tool, is
guided by the information about the changes between the base version and its
variants to find a test that is able to trigger the conflict.

Note: For convenience, the [`tools/get-tools.sh`](`tools/get-tools.sh`) script
automatically downloads and builds UNSETTLE's modules.

## Using UNSETTLE

In a common merge scenario, as the one in the figure above, four versions of the
program under test are required to run UNSETTLE: the base version, variant 1 and
2 versions, and the merge version.  As described in the following table, for the
base version UNSETTLE only requires the source code, for the merge version it
only requires the compiled classes, and for both variants it requires the source
code and the compiled classes.

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
- Merge commit: [193acdb36cd3da9bfc62dd69c4208dff3f0a2b1b](https://github.com/netty/netty/commit/193acdb36cd3da9bfc62dd69c4208dff3f0a2b1b)
- Variant 1 commit: [b3b096834cafc7f348583786d71567e9fa001b55](https://github.com/netty/netty/commit/b3b096834cafc7f348583786d71567e9fa001b55)
- Variant 2 commit: [c2417c253c48bac942decfe923743d2b09d63a5f](https://github.com/netty/netty/commit/c2417c253c48bac942decfe923743d2b09d63a5f)
- Base commit: [2fc18a00f6ac61a365b73dd498dd2e38f1efa823](https://github.com/netty/netty/commit/2fc18a00f6ac61a365b73dd498dd2e38f1efa823)

Note: the base commit can automatically be extracted from project's git
repository, e.g.,

```bash
git merge-base --octopus b3b096834cafc7f348583786d71567e9fa001b55 c2417c253c48bac942decfe923743d2b09d63a5f
```

### Setup

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
(cd variant-1; mvn clean compile -Dmaven.repo.local=$(pwd)/.m2)

# Variant 2
(cd variant-2; mvn clean compile -Dmaven.repo.local=$(pwd)/.m2)

# Merge
(cd merge; mvn clean compile -Dmaven.repo.local=$(pwd)/.m2)
```

4. Collect variant 1's, variant 2's, and merge's dependencies

```bash
# Variant 1
(cd variant-1; mvn dependency:copy-dependencies -Dmaven.repo.local=$(pwd)/.m2 -DoutputDirectory=$(pwd)/.deps)

# Variant 2
(cd variant-2; mvn dependency:copy-dependencies -Dmaven.repo.local=$(pwd)/.m2 -DoutputDirectory=$(pwd)/.deps)

# Merge
(cd merge; mvn dependency:copy-dependencies -Dmaven.repo.local=$(pwd)/.m2 -DoutputDirectory=$(pwd)/.deps)
```

5. Collect variant 1's, variant 2's, and merge's classpath

```bash
# Variant 1
variant_1_classpath=$(cd variant-1; echo $(pwd)/target/classes:$(find .deps -type f -name "*.jar" | sed "s|^|$(pwd)/|g" | tr '\n' ':'))

# Variant 2
variant_2_classpath=$(cd variant-2; echo $(pwd)/target/classes:$(find .deps -type f -name "*.jar" | sed "s|^|$(pwd)/|g" | tr '\n' ':'))

# Merge
merge_classpath=$(cd merge; echo $(pwd)/target/classes:$(find .deps -type f -name "*.jar" | sed "s|^|$(pwd)/|g" | tr '\n' ':'))
```

6. Collect the set of `.java` files involved in the merge commit

```bash
# Get set of files involved in the merge commit
modified_files=$(cd merge; git diff --name-only HEAD^1 src/main/java)

# Path to the files involved in the merge commit under base/
base_modified_files=$(echo "$modified_files" | sed "s|^|base/|g" | tr '\n' ';')

# Path to the files involved in the merge commit under variant-1/
variant_1_modified_files=$(echo "$modified_files" | sed "s|^|variant-1/|g" | tr '\n' ';')

# Path to the files involved in the merge commit under variant-2/
variant_2_modified_files=$(echo "$modified_files" | sed "s|^|variant-2/|g" | tr '\n' ';')
```

### Semantic Conflict Detection

[Changes-Matcher](https://github.com/conflito/changes-matcher) relies on a
configuration file that allows one for some customizable options.  For the
project example the configuration file (e.g., `netty-193acdb-configuration.txt`)
can be configured as

```
# (TODO relative? absolute?) Path to the source directory of the base version
base.src.dir=base/src/main/java

# (TODO relative? absolute?) Path to the source directory of the first variant version
var1.src.dir=variant-1/src/main/java

# (TODO relative? absolute?) Path to the source directory of the second variant version
var2.src.dir=variant-2/src/main/java

# (TODO relative? absolute?) Classpath the first variant version
var1.cp.dir=variant-1/target/classes:variant-1/.deps/easymockclassextension-2.5.2.jar:variant-1/.deps/commons-logging-1.1.1.jar:variant-1/.deps/org.osgi.compendium-1.4.0.jar:variant-1/.deps/junit-4.10.jar:variant-1/.deps/slf4j-api-1.6.1.jar:variant-1/.deps/cglib-nodep-2.2.jar:variant-1/.deps/jmock-2.5.1.jar:variant-1/.deps/objenesis-1.2.jar:variant-1/.deps/protobuf-java-2.3.0.jar:variant-1/.deps/log4j-1.2.16.jar:variant-1/.deps/org.osgi.core-1.4.0.jar:variant-1/.deps/servlet-api-2.5.jar:variant-1/.deps/jboss-logging-spi-2.1.2.GA.jar:variant-1/.deps/hamcrest-library-1.1.jar:variant-1/.deps/slf4j-simple-1.6.1.jar:variant-1/.deps/hamcrest-core-1.1.jar:variant-1/.deps/easymock-2.5.2.jar:variant-1/.deps/jmock-junit4-2.5.1.jar:variant-1/.deps/rxtx-2.1.7.jar:variant-1/.deps/junit-dep-4.4.jar:

# (TODO relative? absolute?) Classpath the second variant version
var2.cp.dir=variant-2/target/classes:variant-2/.deps/easymockclassextension-2.5.2.jar:variant-2/.deps/commons-logging-1.1.1.jar:variant-2/.deps/org.osgi.compendium-1.4.0.jar:variant-2/.deps/slf4j-api-1.6.1.jar:variant-2/.deps/cglib-nodep-2.2.jar:variant-2/.deps/jmock-2.5.1.jar:variant-2/.deps/objenesis-1.2.jar:variant-2/.deps/protobuf-java-2.3.0.jar:variant-2/.deps/log4j-1.2.16.jar:variant-2/.deps/org.osgi.core-1.4.0.jar:variant-2/.deps/servlet-api-2.5.jar:variant-2/.deps/jboss-logging-spi-2.1.2.GA.jar:variant-2/.deps/hamcrest-library-1.1.jar:variant-2/.deps/junit-4.8.2.jar:variant-2/.deps/slf4j-simple-1.6.1.jar:variant-2/.deps/hamcrest-core-1.1.jar:variant-2/.deps/easymock-2.5.2.jar:variant-2/.deps/jmock-junit4-2.5.1.jar:variant-2/.deps/rxtx-2.1.7.jar:variant-2/.deps/junit-dep-4.4.jar:

# (TODO relative? absolute?) Classpath the merge version
merge.cp.dir=merge/target/classes:merge/.deps/easymockclassextension-2.5.2.jar:merge/.deps/commons-logging-1.1.1.jar:merge/.deps/org.osgi.compendium-1.4.0.jar:merge/.deps/junit-4.10.jar:merge/.deps/slf4j-api-1.6.1.jar:merge/.deps/cglib-nodep-2.2.jar:merge/.deps/jmock-2.5.1.jar:merge/.deps/objenesis-1.2.jar:merge/.deps/protobuf-java-2.3.0.jar:merge/.deps/log4j-1.2.16.jar:merge/.deps/org.osgi.core-1.4.0.jar:merge/.deps/servlet-api-2.5.jar:merge/.deps/jboss-logging-spi-2.1.2.GA.jar:merge/.deps/hamcrest-library-1.1.jar:merge/.deps/slf4j-simple-1.6.1.jar:merge/.deps/hamcrest-core-1.1.jar:merge/.deps/easymock-2.5.2.jar:merge/.deps/jmock-junit4-2.5.1.jar:merge/.deps/rxtx-2.1.7.jar:merge/.deps/junit-dep-4.4.jar:
```

Once the configuration file is in place, the `changes-matcher` can be executed as

```bash
java -jar tools/changes-matcher.jar \
  --base <path>[;<path>] \
  --variant1 <path>[;<path>] \
  --variant2 <path>[;<path>] \
  --config <path> \
  --match_only
```

where

- `--base` are the (TODO relative? absolute?) paths to the base version of the files modified in the merge version, use `;` to define more than one path
- `--variant1` are the (TODO relative? absolute?) paths to the first variant version of the files modified in the merge version, use `;` to define more than one path
- `--variant2` are the (TODO relative? absolute?) paths to the second version of the files modified in the merge version, use `;` to define more than one path
- `--config` is the (TODO relative? absolute?) path to the configuration file

Upon a successful execution, this command writes to the stdout the (variable, value)
pairings and the testing goals (target class and methods to cover) for the test
generation step.

Note: By default, [Changes-Matcher](https://github.com/conflito/changes-matcher)
attempts to match any of the known patterns.  However, the `--conflict_name <pattern name>`
option could be used to search for a particular change pattern.  The pattern
available are:
- TODO 1 which matches X
- TODO 2 which matches Y

For the running example, one could run the command above as

```bash
java -jar tools/changes-matcher.jar \
  --base "$base_modified_files" \
  --variant1 "$variant_1_modified_files" \
  --variant2 "$variant_2_modified_files" \
  --config netty-193acdb-configuration.txt \
  --match_only > netty-193acdb-matches.txt
```

which returns

```
[
  [
    (0, org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder),
    (1, decode(org.jboss.netty.channel.ChannelHandlerContext, org.jboss.netty.channel.Channel, org.jboss.netty.buffer.ChannelBuffer))
  ],
  [
    (0, org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder),
    (1, org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder),
    (2, decode(org.jboss.netty.channel.ChannelHandlerContext, org.jboss.netty.channel.Channel, org.jboss.netty.buffer.ChannelBuffer)),
    (3, failIfNecessary(org.jboss.netty.channel.ChannelHandlerContext))
  ]
]

[
  (
    org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder, [
      org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.decode(Lorg/jboss/netty/channel/ChannelHandlerContext;Lorg/jboss/netty/channel/Channel;Lorg/jboss/netty/buffer/ChannelBuffer;)Ljava/lang/Object;
    ]
  ),
  (
    org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder, [
      org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.decode(Lorg/jboss/netty/channel/ChannelHandlerContext;Lorg/jboss/netty/channel/Channel;Lorg/jboss/netty/buffer/ChannelBuffer;)Ljava/lang/Object;,
      org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder.failIfNecessary(Lorg/jboss/netty/channel/ChannelHandlerContext;)V
    ]
  )
]
```

TODO: how does one parse this output?

### Semantic Conflict Revealing

Given [Changes-Matcher's](https://github.com/conflito/changes-matcher) output,
one can now attempt to generate a unit test case that reveals the identified
conflict.  To achieve that, execute the following command

```bash
java -jar tools/evosuite.jar \
  -projectCP <merge classpath> \
  -class <name> \
  -Dcover_methods=<names> \
  -Dregressioncp=<variant-1 classpath> \
  -Dsecond_regressioncp=<variant-2 classpath> \
  -criterion methodcall \
  -Dtest_factory=multi_test \
  -Dassertion_strategy=specific
```

where

- `projectCP` is the classpath of the merge version as `<path[:path]>` (note: on Windows, `:` is represented as `;`)
- `-class` is the qualified name of the class under test. This is outputted by the [Changes-Matcher](https://github.com/conflito/changes-matcher)
- `-Dcover_methods=` are the qualified names of the methods the generated test must cover specified as `classQualifiedName.methodDescriptor;classQualifiedName.methodDescriptor;(...)`. The first method is the one that is allowed to appear directly in the test. These are the testing goals outputted by the [Changes-Matcher](https://github.com/conflito/changes-matcher).
- `-Dregressioncp=` is the classpath of the first variant version as `<path[:path]>` (note: on Windows, `:` is represented as `;`)
- `-Dsecond_regressioncp=` is the classpath of the second variant version as `<path[:path]>` (note: on Windows, `:` is represented as `;`)

The `-criterion`, `-Dtest_factory`, and `assertion_strategy` remain unchanged
between executions.  An additional property `-Ddistance_threshold=]0..1]` is
also available to set the threshold used by the
[test generator](https://github.com/conflito/evosuite/tree/trigger-semantic-conflict-with-latest-evosuiter-version)
to consider objects sufficiently different.

For the running example, one could run the command above as

```bash
java -jar tools/evosuite.jar \
  -projectCP "$merge_classpath" \
  -class "org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder" \
  -Dcover_methods=TODO \
  -Dregressioncp="$variant_1_classpath" \
  -Dsecond_regressioncp="$variant_2_classpath" \
  -criterion methodcall \
  -Dtest_factory=multi_test \
  -Dassertion_strategy=specific
```

which, by default, writes to the `evosuite-tests` directory the following test
case that reveals the semantic conflict

```java
package org.jboss.netty.handler.codec.frame;

import org.junit.Test;
import static org.junit.Assert.*;
import static org.evosuite.shaded.org.mockito.Mockito.*;
import org.evosuite.AllFieldsCalculator;
import org.evosuite.runtime.EvoRunner;
import org.evosuite.runtime.EvoRunnerParameters;
import org.evosuite.runtime.ViolatedAssumptionAnswer;
import org.jboss.netty.buffer.BigEndianHeapChannelBuffer;
import org.jboss.netty.channel.Channel;
import org.jboss.netty.channel.ChannelHandlerContext;
import org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder;
import org.junit.runner.RunWith;
import org.evosuite.AllFieldsCalculator;

@RunWith(EvoRunner.class) @EvoRunnerParameters(mockJVMNonDeterminism = true, useVFS = true, useVNET = true, resetStaticState = true, separateClassLoader = true, useJEE = true)
public class LengthFieldBasedFrameDecoder_ESTest extends LengthFieldBasedFrameDecoder_ESTest_scaffolding {

  @Test(timeout = 4000)
  public void test0()  throws Throwable  {
      LengthFieldBasedFrameDecoder lengthFieldBasedFrameDecoder0 = new LengthFieldBasedFrameDecoder(662, 3, 3, 662, 3);
      ChannelHandlerContext channelHandlerContext0 = mock(ChannelHandlerContext.class, new ViolatedAssumptionAnswer());
      Channel channel0 = mock(Channel.class, new ViolatedAssumptionAnswer());
      byte[] byteArray0 = new byte[5];
      byteArray0[0] = (byte) (-1);
      byteArray0[1] = (byte)109;
      byteArray0[2] = (byte)76;
      byteArray0[3] = (byte)0;
      byteArray0[4] = (byte) (-45);
      BigEndianHeapChannelBuffer bigEndianHeapChannelBuffer0 = new BigEndianHeapChannelBuffer(byteArray0);
      Object object0 = lengthFieldBasedFrameDecoder0.decode(channelHandlerContext0, channel0, bigEndianHeapChannelBuffer0);
      assertNull(object0);

      LengthFieldBasedFrameDecoder lengthFieldBasedFrameDecoder1 = lengthFieldBasedFrameDecoder0.setFailImmediatelyOnTooLongFrame(false);
      assertNotNull(lengthFieldBasedFrameDecoder1);

      long long0 = AllFieldsCalculator.allFieldsMethod(lengthFieldBasedFrameDecoder0);
      assertEquals((-2375579320135771983L), long0);

      AllFieldsCalculator.allFieldsMethod(channelHandlerContext0);
      AllFieldsCalculator.allFieldsMethod(channel0);
      AllFieldsCalculator.allFieldsMethod(bigEndianHeapChannelBuffer0);
      long long1 = AllFieldsCalculator.allFieldsMethod(object0);
      assertEquals(0L, long1);

      long long2 = AllFieldsCalculator.allFieldsMethod(lengthFieldBasedFrameDecoder1);
      assertEquals((-2375579320135771983L), long2);
  }
}
```

To verify whether the generated test case does indeed reveal the conflict
executed the following procedure

1. Compile the generated test on the merge version

```bash
evosuite_jar=$(pwd)/tools/evosuite.jar

(cd evosuite-tests; javac -cp $merge_classpath:$evosuite_jar org/jboss/netty/handler/codec/frame/LengthFieldBasedFrameDecoder_ESTest.java)
```

2. Run the generated test on the merge version (which should TODO fail? pass?)

```bash
(cd evosuite-tests; java -cp .:$merge_classpath:$evosuite_jar org.junit.runner.JUnitCore org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder_ESTest)
```

3. Run the generated test on the variant 1 version (which should TODO fail? pass?)
TODO does one need to recompile it under variant 1 version?

```bash
(cd evosuite-tests; java -cp .:$variant_1_classpath:$evosuite_jar org.junit.runner.JUnitCore org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder_ESTest)
```

4. Run the generated test on the variant 2 version (which should TODO fail? pass?)
TODO does one need to recompile it under variant 2 version?

```bash
(cd evosuite-tests; java -cp .:$variant_2_classpath:$evosuite_jar org.junit.runner.JUnitCore org.jboss.netty.handler.codec.frame.LengthFieldBasedFrameDecoder_ESTest)
```
