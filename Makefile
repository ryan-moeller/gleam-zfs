# Copyright (c) 2026 Ryan Moeller
# SPDX-License-Identifier: BSD-2-Clause

CC	=	cc
#CFLAGS	=	-O2 -Wall -fPIC -pthread -std=c23
CFLAGS	=	-O0 -g -Wall -Werror -fPIC -pthread -std=c23
LDFLAGS	=	-Bmold -shared

SRCTOP	:=	/usr/src
ZFSTOP	:=	$(SRCTOP)/sys/contrib/openzfs
CFLAGS	+=	-include $(ZFSTOP)/include/os/freebsd/spl/sys/ccompile.h \
		-I$(ZFSTOP)/include \
		-I$(ZFSTOP)/lib/libspl/include \
		-I$(ZFSTOP)/lib/libspl/include/os/freebsd \
		-I$(ZFSTOP)/lib/libzpool/include

ERLANG	:=	erlang29
PREFIX	:=	/usr/local
ERLTOP	:=	$(PREFIX)/lib/$(ERLANG)
ERL_INCLUDE	:=	$(ERLTOP)/usr/include
ERL_LIB	:=	$(ERLTOP)/usr/lib
CFLAGS	+=	-I$(ERL_INCLUDE)
LDFLAGS	+=	-L$(ERL_LIB) -lei

TARGET	=	priv/zfs_drv.so
SRCS	=	zfs_drv.c
OBJS	=	$(SRCS:.c=.o)

all:	$(TARGET)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

clean:
	rm -f $(OBJS) $(TARGET)

.PHONY: all clean
