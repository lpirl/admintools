#!/usr/bin/env python3
import logging
from  os import statvfs

from argparse import ArgumentParser

class HumanReadableSizeConverter(object):

    PREFIX_EXPONENTS = {
        None: 0,
        "K": 1,
        "M": 2,
        "G": 3,
        "T": 4,
        "P": 5,
        "E": 6,
        "Z": 7,
        "Y": 8,
    }

    DIGIT_STRINGS = [str(i) for i in range(10)]

    def __init__(self, metric=False):
        if metric:
            self.base = 1000
        else:
            self.base = 1024
        logging.debug("converting sizes using base {0!r}".format(
            self.base
        ))

    def factor_for_prefix(self, prefix):
        return self.base ** self.PREFIX_EXPONENTS[prefix]

    def has_prefix(self, human_readable):
        return human_readable[-1] not in self.DIGIT_STRINGS

    def get_prefix_from_human_readable(self, human_readable):
        if self.has_prefix(human_readable):
            return human_readable[-1]
        else:
            return None

    def extract_int_from_human_readable(self, human_readable):
        if self.has_prefix(human_readable):
            return int(human_readable[:-1])
        return int(human_readable)

    def human_readable_to_bytes(self, human_size):
        prefix = self.get_prefix_from_human_readable(human_size)
        logging.debug("prefix: {0}".format(prefix))
        number = self.extract_int_from_human_readable(human_size)
        logging.debug("number: {0}".format(number))
        nbytes = number * self.factor_for_prefix(prefix)
        logging.debug("{0} human readable means {1} bytes".format(
            human_size, nbytes
        ))
        return nbytes

    def bytes_to_human_readable(self, size, prefix):
        dividend = float(self.factor_for_prefix(prefix))
        converted_size = round(size/dividend, 1)
        return str(converted_size) + prefix

def setup_argarser():
    """
    Initializes command line arguments.
    """
    argparser = ArgumentParser(
        description='Prints message upon exceeded quota.'
    )
    argparser.add_argument("-d", "--debug", action="store_true",
                           help="show debug output")
    argparser.add_argument("-m", "--metric", action="store_true",
                           help="resolve prefixes with factor 1000 " +
                                "instead of 1024")
    argparser.add_argument('quota', type=str,
                            help='maximum quota (K|M|G|T|P|E|Z|Y)')
    argparser.add_argument('mounts', metavar="mountpoint", type=str, nargs='+',
                            help='device or mount point')
    return argparser

def get_bytes_used_from_statvfs(stat):
    #            (total_blocks - free_blocks  ) * block_size
    bytes_used = (stat.f_blocks - stat.f_bfree) * stat.f_frsize
    logging.debug("stat {0} has {1} bytes used".format(stat, bytes_used))
    return bytes_used

if __name__ == '__main__':
    """
    Invoked when started from command line.
    """

    # set up & get command line arguments
    argparser = setup_argarser()
    args = argparser.parse_args()

    # logging:
    logger = logging.getLogger()
    logger.setLevel(logging.WARN)
    if args.debug:
        logger.setLevel(logging.DEBUG)

    logging.debug("parsed args: {0!r}".format(args))

    converter = HumanReadableSizeConverter(args.metric)

    max_quota = converter.human_readable_to_bytes(args.quota)
    logging.debug("maximum quota in bytes: {0}".format(max_quota))

    mounts_stats = [statvfs(d) for d in args.mounts]

    mounts_bytes_used = map(get_bytes_used_from_statvfs, mounts_stats)

    current_size = sum(mounts_bytes_used)
    logging.debug("sum of bytes used: {0}".format(current_size))

    if current_size > max_quota:
        prefix = converter.get_prefix_from_human_readable(args.quota)
        logging.critical(
            "mounts {0} exceed quota of {1}: {2}".format(
                args.mounts,
                args.quota,
                converter.bytes_to_human_readable(current_size, prefix)
            )
        )
        exit(1)
