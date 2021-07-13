# UNSETTLE (aUtomatic uNit teSt gEneraTion for semanTic confLict dEtection)

## Building UNSETTLE

### Changes-Matcher

**Changes-Matcher** uses [Maven](https://maven.apache.org).  To build Changes-Matcher on the command line, install `maven` and then execute the following command:

```bash
mvn compile
```

To create a binary distribution that includes all dependencies you can also use [Maven](https://maven.apache.org) as:

```bash
mvn compile assembly:single
```

### EvoSuite

Similarly, to build the **EvoSuite** distribution, we execute the following command in the EvoSuite project folder:

```bash
mvn package -DskipTests=true
```

## Using UNSETTLE

To use this tool, we need four versions/copies of a system, one for the base version of the merge, one for each of its variants, and one for the merge version.

We only need the source code of the base version and the compiled classes for the merge version. For both variants, we need the source code and the compiles classes.

To specify them, we use a configuration file like the following:

```
# Path to the source directory of the base version
base.src.dir=path/to/replace

# Path to the source directory of the first variant version
var1.src.dir=path/to/replace

# Path to the source directory of the second variant version
var2.src.dir=path/to/replace

# Path to the classpath directory of the first variant version
var1.cp.dir=path/to/replace

# Path to the classpath directory of the second variant version
var2.cp.dir=path/to/replace

# Path to the classpath directory of the merge version
merge.cp.dir=path/to/replace
```

where
- `base.src.dir` is the path to the source code folder of the base version
- `var1.src.dir` is the path to the source code folder of the first variant
- `var2.src.dir` is the path to the source code folder of the second variant
- `var1.cp.dir` is the path to the compiled classes folders of the first variant
- `var2.cp.dir` is the path to the compiled classes folders of the second variant
- `merge.cp.dir` is the path to the compiled classes folders of the merge version

If we are not concerned with generating a test and only want to search for matches of patterns, it does not matter what we specify in the last three properties. However, they still need to be specified.

To run UNSETTLE and generate a test, we need the Evosuite executable. By default, UNSETTLE uses a jar called "evosuite.jar" that is in the same folder where we run the tool. Alternatively, we can use the `evosuite.location` property to specify a different location for the jar that can have a different name.

To run UNSETTLE and generate a test, we use the following command (this will run the entire pipeline and attempt to generate a test that reveals any detected change pattern):

```bash
java -jar target/matcher-0.0.1-SNAPSHOT-jar-with-dependencies.jar \
  --base ... \
  --variant1 ... \
  --variant2 ... \
  --config ...
```

where
- `--base` are the paths to the base version of the modified files that must be specified as `<path>;<path>;(...)`
- `--variant1` are the paths to the first variant version of the modified files that must be specified as  `<path>;<path>;(...)`
- `--variant2` are the paths to the second version of the modified files that must be specified as  `<path>;<path>;(...)`
- `--config` is the path to the configuration file

### Using Changes-Matcher

If we do not want to generate a test and want only to run the matching aspect of the tool, we use the following command:

```bash
java -jar target/matcher-0.0.1-SNAPSHOT-jar-with-dependencies.jar \
  --base ... \
  --variant1 ... \
  --variant2 ... \
  --config ... \
  --match_only
```

This will output the (variable, value) pairings and the testing goals (target class and methods to cover) for test generation.

If we want to test a specific change pattern, we can use the `--conflict_name <name>` where the `<name>` is the name of the change pattern to be tested.

### Using EvoSuite

If you want to run EvoSuite only (i.e. skip the matching step) you use the following command:

```bash
java -jar <jar> \
  -projectCP ... \
  -class ... \
  -Dcover_methods=... \
  -Dregressioncp=... \
  -Dsecond_regressioncp=... \
  -criterion methodcall \
  -Dtest_factory=multi_test \
  -Dassertion_strategy=specific
```

where
- `-projectCP` are the paths to the compiled classes folders of the merge version, specified as `<path>;<path>;(...)`.
- `-class` is the qualified name of the target class. This is outputted by the Changes-Matcher.
- `-Dcover_methods=` are the qualified names of the methods the generated test must cover specified as `classQualifiedName.methodDescriptor;classQualifiedName.methodDescriptor;(...)`. The first method is the one that is allowed to appear directly in the test. These are the testing goals outputted by the Changes-Matcher.
- `-Dregressioncp=` are the paths to the compiled classes folders of the first variant version, specified as `<path>;<path>;(...)`.
- `-Dsecond_regressioncp=` are the paths to the compiled classes folders of the second variant version, specified as `<path>;<path>;(...)`.

The `-criterion`, `-Dtest_factory`, and `assertion_strategy` remain unchanged between executions. If we want to tell EvoSuite the threshold to consider objects sufficiently different, we can use the `-Ddistance_threshold=]0..1]` property.