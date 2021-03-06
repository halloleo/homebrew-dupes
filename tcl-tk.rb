require "formula"

class TclTk < Formula
  homepage "http://www.tcl.tk/"
  url "https://downloads.sourceforge.net/project/tcl/Tcl/8.6.3/tcl8.6.3-src.tar.gz"
  version "8.6.3"
  sha1 "026b4b6330205bdc49af12332ee17c2b01f76d37"

  keg_only :provided_by_osx,
    "Tk installs some X11 headers and OS X provides an (older) Tcl/Tk."

  option "enable-threads", "Build with multithreading support"
  option "without-tcllib", "Don't build tcllib (utility modules)"
  option "without-tk", "Don't build the Tk (window toolkit)"
  option "with-x11", "Build X11-based Tk instead of Aqua-based Tk"

  depends_on :x11 => :optional

  resource "tk" do
    url "http://downloads.sourceforge.net/project/tcl/Tcl/8.6.3/tk8.6.3-src.tar.gz"
    version "8.6.3"
    sha1 "244ddc0f64cc3d429c9d86135d0bbe2cf06c9360"
  end

  resource "tcllib" do
    url "https://github.com/tcltk/tcllib/archive/tcllib_1_16.tar.gz"
    sha1 "4d677337f082c3ebc2a682a3d9b2fb4639ed7d0c"
  end

  # sqlite won't compile on Tiger due to missing function;
  # patch submitted upstream: http://thread.gmane.org/gmane.comp.db.sqlite.general/83257
  patch :DATA if MacOS.version < :leopard

  def install
    args = ["--prefix=#{prefix}", "--mandir=#{man}"]
    args << "--enable-threads" if build.include? "enable-threads"
    args << "--enable-64bit" if MacOS.prefer_64_bit?

    cd "unix" do
      system "./configure", *args
      system "make"
      system "make install"
      system "make install-private-headers"
      ln_s bin+"tclsh8.6", bin+"tclsh"
    end

    if build.with? "tk"
      ENV.prepend_path "PATH", bin # so that tk finds our new tclsh

      resource("tk").stage do
        args = ["--prefix=#{prefix}", "--mandir=#{man}", "--with-tcl=#{lib}"]
        args << "--enable-threads" if build.include? "enable-threads"
        args << "--enable-64bit" if MacOS.prefer_64_bit?

        if build.with? "x11"
          args << "--with-x"
        else
          args << "--enable-aqua=yes"
          args << "--without-x"
        end

        cd "unix" do
          system "./configure", *args
          system "make", "TK_LIBRARY=#{lib}"
          # system "make test"  # for maintainers
          system "make install"
          system "make install-private-headers"
          ln_s bin+"wish8.6", bin+"wish"
        end
      end
    end

    if build.with? "tcllib"
      resource("tcllib").stage do
        system "./configure", "--prefix=#{prefix}"
        system "make", "install"
      end
    end
  end
end

__END__
diff --git a/pkgs/sqlite3.8.7.1/generic/sqlite3.c b/pkgs/sqlite3.8.7.1/generic/sqlite3.c
index 5c8e1c1..bb3fdfc 100644
--- a/pkgs/sqlite3.8.7.1/generic/sqlite3.c
+++ b/pkgs/sqlite3.8.7.1/generic/sqlite3.c
@@ -16505,6 +16505,7 @@ SQLITE_PRIVATE void sqlite3MemSetDefault(void){
 #include <sys/sysctl.h>
 #include <malloc/malloc.h>
 #include <libkern/OSAtomic.h>
+
 static malloc_zone_t* _sqliteZone_;
 #define SQLITE_MALLOC(x) malloc_zone_malloc(_sqliteZone_, (x))
 #define SQLITE_FREE(x) malloc_zone_free(_sqliteZone_, (x));
@@ -16512,6 +16513,29 @@ static malloc_zone_t* _sqliteZone_;
 #define SQLITE_MALLOCSIZE(x) \
         (_sqliteZone_ ? _sqliteZone_->size(_sqliteZone_,x) : malloc_size(x))
 
+/*
+** If compiling for Mac OS X 10.4, the OSAtomicCompareAndSwapPtrBarrier
+** function will not be available, but individual 32-bit and 64-bit
+** versions will.
+*/
+
+#ifdef __MAC_OS_X_MIN_REQUIRED
+# include <AvailabilityMacros.h>
+#elif defined(__IPHONE_OS_MIN_REQUIRED)
+# include <Availability.h>
+#endif
+
+typedef int fc_atomic_int_t;
+#if (MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_4 || __IPHONE_VERSION_MIN_REQUIRED >= 20100)
+# define fc_atomic_ptr_cmpexch(O,N,P) OSAtomicCompareAndSwapPtrBarrier ((void *) (O), (void *) (N), (void **) (P))
+#else
+# if __ppc64__ || __x86_64__
+#  define fc_atomic_ptr_cmpexch(O,N,P) OSAtomicCompareAndSwap64Barrier ((int64_t) (O), (int64_t) (N), (int64_t*) (P))
+# else
+#  define fc_atomic_ptr_cmpexch(O,N,P) OSAtomicCompareAndSwap32Barrier ((int32_t) (O), (int32_t) (N), (int32_t*) (P))
+# endif
+#endif
+
 #else /* if not __APPLE__ */
 
 /*
@@ -16698,7 +16722,7 @@ static int sqlite3MemInit(void *NotUsed){
     malloc_zone_t* newzone = malloc_create_zone(4096, 0);
     malloc_set_zone_name(newzone, "Sqlite_Heap");
     do{
-      success = OSAtomicCompareAndSwapPtrBarrier(NULL, newzone, 
+      success = fc_atomic_ptr_cmpexch(NULL, newzone,
                                  (void * volatile *)&_sqliteZone_);
     }while(!_sqliteZone_);
     if( !success ){
