# 
# Rakefile
# kxsmb project
# https://github.com/kolyvan/kxsmb/
#
# Created by Kolyvan on 29.03.13.
#

#
# Copyright (c) 2013 Konstantin Bukreev All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# - Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
# 
# - Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

require "pathname"
require "fileutils"

# utils

def system_or_exit(cmd, stdout = nil)
  puts "Executing #{cmd}"
  cmd += " >#{stdout}" if stdout
  system(cmd) or raise "******** Build failed ********"
end

def copyIfNotExists(file, from, to)

	dest = Pathname.new(to)
	dest.mkdir unless dest.exist?

	unless (dest + file).exist?
		source = Pathname.new(from) + file
		FileUtils.copy source, dest	
		p "copy #{source} -> #{dest}"
	end
end

def cleanOrMkDir(path)
	dest = Pathname.new path
	if dest.exist?
		FileUtils.rm Dir.glob("#{path}/*.a")
	else
		dest.mkdir
	end	
end

def cleanDir(path)
	dest = Pathname.new path
	if dest.exist?
		FileUtils.rm Dir.glob("#{path}/*.a")	
	end	
end

# versions

SDK_VERSION='6.1'
IOS_MIN_VERSION='5.0'
SAMBA_VERSION='4.0.6'

# samba source

SAMBA_BASE_URL="http://ftp.samba.org/pub/samba/"

#pathes

XCODE_PATH='/Applications/Xcode.app/Contents/Developer'
SIM_SDK_PATH=XCODE_PATH + "/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator#{SDK_VERSION}.sdk"
IOS_SDK_PATH=XCODE_PATH + "/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS#{SDK_VERSION}.sdk"

#SAMBA_PATH="samba-#{SAMBA_VERSION}/source3"
SAMBA_FOLDER="samba"
SAMBA_SOURCE_PATH="#{SAMBA_FOLDER}/source3"
EXT_INCLUDE_PATH='tmp/include'

# configure arguments

IOS_GCC_PATH=XCODE_PATH+'/Platforms/iPhoneOS.platform/Developer/usr/llvm-gcc-4.2/bin/arm-apple-darwin10-llvm-gcc-4.2'
SIM_GCC_PATH=XCODE_PATH+'/usr/llvm-gcc-4.2/bin/i686-apple-darwin11-llvm-gcc-4.2' 

CF_FLAGS='-pipe -Wno-trigraphs -fpascal-strings -Os -Wreturn-type -Wunused-variable -fmessage-length=0 -gdwarf-2'

IOS_CF_FLAGS='-mcpu=cortex-a8 -mfpu=neon -ftree-vectorize -mfloat-abi=softfp'
IOS_LD_FLAGS='-mcpu=cortex-a8'

ARM7_CF_FLAGS="-march=armv7 #{IOS_CF_FLAGS} #{CF_FLAGS}"
ARM7_LD_FLAGS="-march=armv7 #{IOS_LD_FLAGS}"

ARM7s_CF_FLAGS="-march=armv7s #{IOS_CF_FLAGS} #{CF_FLAGS}"
ARM7s_LD_FLAGS="-march=armv7s #{IOS_LD_FLAGS}"

I386_CF_FLAGS="-march=i386 #{CF_FLAGS}"
I386_LD_FLAGS='-march=i386'

SMB_ARGS = [
'--disable-shared',
'--enable-static',
'--without-readline',
'--with-libsmbclient',
'--without-libnetapi',
'--without-libsmbsharemodes',
'--without-cluster-support',
'--without-ldap',
'--disable-swat',
'--disable-cups',
'--disable-iprint',
'libreplace_cv_HAVE_C99_VSNPRINTF=yes',
'samba_cv_CC_NEGATIVE_ENUM_VALUES=yes',
]

SIM_SMB_ARGS = [
'--enable-debug',
]

IOS_SMB_ARGS = [			
'--enable-cross-compile',
'ac_cv_header_libunwind_h=no',
'ac_cv_header_execinfo_h=no',
'ac_cv_header_rpcsvc_ypclnt_h=no',
'ac_cv_file__proc_sys_kernel_core_pattern=no',
'ac_cv_func_fdatasync=no',
'libreplace_cv_HAVE_GETADDRINFO=no',
'samba_cv_SYSCONF_SC_NPROCESSORS_ONLN=no',
'samba_cv_big_endian=no',
'samba_cv_little_endian=yes',
'--host=arm-apple-darwin10',
'--build=x86',
]

# libs

SMB_LIBS = [
'libsmbclient',
'libtalloc',
'libtdb',
'libwbclient',
]

# functions

def mkArgs(sdkPath, platformArgs, gccPath, cfFlags, ldFlags)

	extInclude = Pathname.new(EXT_INCLUDE_PATH).realpath

	args = SMB_ARGS + platformArgs
	args << "CC=#{gccPath}"
	args << "CPPFLAGS=\"-I#{sdkPath}/usr/include -I#{extInclude}\""
	args << "CFLAGS=-\"std=gnu99 -no-cpp-precomp -miphoneos-version-min=#{IOS_MIN_VERSION} -isysroot #{sdkPath} -I#{sdkPath}/usr/include #{cfFlags}\""
	args << "LDFLAGS=\"-miphoneos-version-min=#{IOS_MIN_VERSION} -isysroot #{sdkPath} -L#{sdkPath}/usr/lib -L#{sdkPath}/usr/lib/system #{ldFlags}\""
	
	args.join(' ')
end

def buildArch(arch)

	case arch
	when 'i386'
		args = mkArgs(SIM_SDK_PATH, SIM_SMB_ARGS, SIM_GCC_PATH, I386_CF_FLAGS, I386_LD_FLAGS)
	when 'armv7'
		args = mkArgs(IOS_SDK_PATH, IOS_SMB_ARGS, IOS_GCC_PATH, ARM7_CF_FLAGS, ARM7_LD_FLAGS)
	when 'armv7s'	
		args = mkArgs(IOS_SDK_PATH, IOS_SMB_ARGS, IOS_GCC_PATH, ARM7s_CF_FLAGS, ARM7s_LD_FLAGS)
	else
		raise "Build failed: unknown arch: #{arch}"
	end
	
	p args
	
	system_or_exit "cd #{SAMBA_SOURCE_PATH}; ./autogen.sh"
	system_or_exit "cd #{SAMBA_SOURCE_PATH}; ./configure #{args}"

	SMB_LIBS.each do |x|
		system_or_exit "cd #{SAMBA_SOURCE_PATH}; make #{x}"		
	end	

	dest = Pathname.new("#{SAMBA_SOURCE_PATH}/bin/#{arch}")	
	cleanOrMkDir(dest)

	SMB_LIBS.each do |x|
		FileUtils.move Pathname.new("#{SAMBA_SOURCE_PATH}/bin/#{x}.a"), dest		
	end

	system_or_exit "cd #{SAMBA_SOURCE_PATH}; make clean"
end

def checkExtInclude
	extInclude = Pathname.new(EXT_INCLUDE_PATH)
	extInclude.mkpath unless extInclude.exist?	 
	copyIfNotExists('crt_externs.h', "#{SIM_SDK_PATH}/usr/include/", extInclude.realpath)
end

# tasks

desc "Build smb armv7 libs"
task :build_smb_armv7 do
	checkExtInclude	
	buildArch('armv7')	
end

desc "Build smb armv7s libs"
task :build_smb_armv7s do
	checkExtInclude	
	buildArch('armv7s')	
end

desc "Build smb i386 libs"
task :build_smb_i386 do	
	buildArch('i386')	
end

desc "Build smb universal libs"
task :build_smb_universal do	
	
	dest = Pathname.new("#{SAMBA_SOURCE_PATH}/bin/universal")
	dest.mkdir unless dest.exist?

	SMB_LIBS.each do |x|		
		args = "-create -arch armv7 #{SAMBA_SOURCE_PATH}/bin/armv7/#{x}.a -arch armv7 #{SAMBA_SOURCE_PATH}/bin/armv7s/#{x}.a -arch i386 #{SAMBA_SOURCE_PATH}/bin/i386/#{x}.a -output #{dest}/#{x}.a"
		system_or_exit "lipo #{args}"
	end	
end

desc "Copy smb headers"
task :copy_headers do		
	copyIfNotExists('libsmbclient.h', "#{SAMBA_SOURCE_PATH}/include/", 'libs')
    copyIfNotExists('talloc.h', "#{SAMBA_FOLDER}/lib/talloc/", 'libs')
    copyIfNotExists('talloc_stack.h', "#{SAMBA_FOLDER}/lib/util/", 'libs')
end	

desc "Copy smb libs"
task :copy_libs do		
	
	dest = Pathname.new('libs')
	dest.mkdir unless dest.exist?

	from = Pathname.new("#{SAMBA_SOURCE_PATH}/bin/universal")

	SMB_LIBS.each do |x|
		source = from + "#{x}.a"
		FileUtils.move source, dest	
		p "copy #{source} -> #{dest}"
	end
end	

desc "Clean"
task :clean do
	cleanDir("#{SAMBA_SOURCE_PATH}/bin/armv7")
	cleanDir("#{SAMBA_SOURCE_PATH}/bin/armv7s")
	cleanDir("#{SAMBA_SOURCE_PATH}/bin/i386")	
	cleanDir("#{SAMBA_SOURCE_PATH}/bin/universal")	

	system_or_exit "cd #{SAMBA_SOURCE_PATH}; make clean"	
end

desc "Retrieve samble archive"
task :retrieve_samba do

	p = Pathname.new "#{SAMBA_SOURCE_PATH}"
 	unless p.exist?

 		name = "samba-#{SAMBA_VERSION}"
 		file = "#{name}.tar.gz"
		url = "#{SAMBA_BASE_URL}#{file}"

 		p "retrieving samba from #{url}"
		system_or_exit "/usr/bin/curl -Ls --output #{file} #{url}"

		p "extracting samba from archive"
		system_or_exit "tar -zxf #{file}"

		Pathname.new(file).delete
		Pathname.new(name).rename SAMBA_FOLDER
 	end

end

task :build_all => [:retrieve_samba, :build_smb_armv7, :build_smb_armv7s, :build_smb_i386, :build_smb_universal, :copy_libs, :copy_headers] 
task :default => [:build_all]
