#!/bin/bash

# Script to test how much bloating a large project will suffer when using
# tinyformat, vs alternatives.  Call as
#
# C99 printf            :  bloat_test.sh [-O3]
# C++ Format            :  bloat_test.sh [-O3] -DUSE_CPPFORMAT
# tinyformat            :  bloat_test.sh [-O3] -DUSE_TINYFORMAT
# tinyformat, no inlines:  bloat_test.sh [-O3] -DUSE_TINYFORMAT -DUSE_TINYFORMAT_NOINLINE
# boost::format         :  bloat_test.sh [-O3] -DUSE_BOOST
# std::iostream         :  bloat_test.sh [-O3] -DUSE_IOSTREAMS
#
# Note: to test the NOINLINE version of tinyformat, you need to remove the few
# inline functions in the tinyformat::detail namespace, and put them into a
# file tinyformat.cpp.  Then rename that version of tinyformat.h into
# tinyformat_noinline.h


prefix=_bloat_test_tmp_
numTranslationUnits=100

rm -f $prefix??.cpp ${prefix}main.cpp ${prefix}all.h

template='
#ifdef USE_BOOST

#include <boost/format.hpp>
#include <iostream>

void doFormat_a()
{
    std::cout << boost::format("%s\n") % "somefile.cpp";
    std::cout << boost::format("%s:%d\n") % "somefile.cpp"% 42;
    std::cout << boost::format("%s:%d:%s\n") % "somefile.cpp"% 42% "asdf";
    std::cout << boost::format("%s:%d:%d:%s\n") % "somefile.cpp"% 42% 1% "asdf";
    std::cout << boost::format("%s:%d:%d:%d:%s\n") % "somefile.cpp"% 42% 1% 2% "asdf";
}

#elif defined(USE_CPPFORMAT)

#include "../format.h"

void doFormat_a()
{
    fmt::Print("{}\n", "somefile.cpp");
    fmt::Print("{}:{}\n", "somefile.cpp", 42);
    fmt::Print("{}:{}:{}\n", "somefile.cpp", 42, "asdf");
    fmt::Print("{}:{}:{}:{}\n", "somefile.cpp", 42, 1, "asdf");
    fmt::Print("{}:{}:{}:{}:{}\n", "somefile.cpp", 42, 1, 2, "asdf");
}

#elif defined(USE_IOSTREAMS)

#include <iostream>

void doFormat_a()
{
    std::cout << "somefile.cpp" << "\n";
    std::cout << "somefile.cpp" << 42 << "\n";
    std::cout << "somefile.cpp" << 42 << "asdf" << "\n";
    std::cout << "somefile.cpp" << 42 << 1 << "asdf" << "\n";
    std::cout << "somefile.cpp" << 42 << 1 << 2 << "asdf" << "\n";
}

#else
#ifdef USE_TINYFORMAT
#   ifdef USE_TINYFORMAT_NOINLINE
#       include "tinyformat_noinline.h"
#   else
#       include "tinyformat.h"
#   endif
#   define PRINTF tfm::printf
#else
#   include <stdio.h>
#   define PRINTF ::printf
#endif

void doFormat_a()
{
    PRINTF("%s\n", "somefile.cpp");
    PRINTF("%s:%d\n", "somefile.cpp", 42);
    PRINTF("%s:%d:%s\n", "somefile.cpp", 42, "asdf");
    PRINTF("%s:%d:%d:%s\n", "somefile.cpp", 42, 1, "asdf");
    PRINTF("%s:%d:%d:%d:%s\n", "somefile.cpp", 42, 1, 2, "asdf");
}
#endif
'

# Generate all the files
echo "#include \"${prefix}all.h\"" >> ${prefix}main.cpp
echo '
#ifdef USE_TINYFORMAT_NOINLINE
#include "tinyformat.cpp"
#endif

int main()
{' >> ${prefix}main.cpp

for ((i=0;i<$numTranslationUnits;i++)) ; do
    n=$(printf "%03d" $i)
    f=${prefix}$n.cpp
    echo "$template" | sed -e "s/doFormat_a/doFormat_a$n/" -e "s/42/$i/" > $f
    echo "doFormat_a$n();" >> ${prefix}main.cpp
    echo "void doFormat_a$n();" >> ${prefix}all.h
done

echo "return 0; }" >> ${prefix}main.cpp


# Compile
time g++ ${prefix}???.cpp ${prefix}main.cpp $* -o ${prefix}.out
ls -sh ${prefix}.out
strip ${prefix}.out
ls -sh ${prefix}.out
