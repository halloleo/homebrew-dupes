require "formula"

class Make < Formula
  homepage "https://www.gnu.org/software/make/"
  url "http://ftpmirror.gnu.org/make/make-4.1.tar.bz2"
  mirror "https://ftp.gnu.org/gnu/make/make-4.1.tar.bz2"
  sha1 "0d701882fd6fd61a9652cb8d866ad7fc7de54d58"

  depends_on "guile" => :optional

  deprecated_option "default-names" => "with-default-names"
  option "with-default-names", "Do not prepend 'g' to the binary"

  def install
    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
    ]

    args << "--with-guile" if build.with? "guile"
    args << "--program-prefix=g" if build.without? "default-names"

    system "./configure", *args
    system "make", "install"
  end
end
