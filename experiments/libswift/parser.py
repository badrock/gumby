#!/usr/bin/env python
import sys
import os
import glob
from sys import argv

# parses the stderr output of each libswift client
def parse_stderr(logDir, outputDir, clientName):

    print >> sys.stderr, "Parsing stderr output of: {0}".format( clientName )

    logfile = os.path.join(logDir, '00000.err')
    datafile = os.path.join(outputDir, clientName + '.err')
    if not os.path.exists( logfile ) or not os.path.isfile( logfile ):
        print >> sys.stderr, "Either the input or the output file is missing"
        exit(1)
    if os.path.exists( datafile ):
        print >> sys.stderr, "Output already present"
        exit(1)
        
    fl = None
    fd = None
    try:
        fl = open( logfile, 'r' )
        fd = open( datafile, 'w' )
        fd.write( "time percent upload download\n0 0 0 0\n" )
        relTime = 0
        up_bytes = 0
        down_bytes = 0
        for line in fl:
            if line[:5] == 'SLEEP':
                relTime += 1
            elif line[:4] == 'done' or line[:4] == 'DONE':
                # Split over ' ', then over ',', then over '(', then over ')', and keep it all in one array
                split = reduce( lambda x,y: x + y.split( ')' ), reduce(lambda x,y: x + y.split( '(' ), reduce(lambda x,y: x + y.split( ',' ), line.split( ' ' ), []), []), [])
                dlspeed = (int(split[16]) - down_bytes) / 1024.0
                down_bytes = int(split[16])
                upspeed = (int(split[10]) - up_bytes) / 1024.0
                up_bytes = int(split[10])
                                    
                percent = 0
                if int(split[3]) > 0:
                    percent = 100.0 * ( float(int(split[1])) / float(int(split[3])) )
                    
                fd.write( "{0} {1} {2} {3}\n".format( relTime, percent, upspeed, dlspeed ) )
                relTime += 1
    finally:
        try:
            if fd:
                fd.close()
        except Exception:
            pass
        try:
            if fl:
                fl.close()
        except Exception:
            pass


# parses the ledbat log of each libswift client
def parse_ledbat(logDir, outputDir, clientName):

    print >> sys.stderr, "Parsing ledbat of: {0}".format( clientName )

    # input file
    logfiles = glob.glob(os.path.join(logDir, '*ledbat*'))
    # output congestion control window
    ccfile = os.path.join(outputDir, clientName + '.cc')

    if len(logfiles) > 1:
        print >> sys.stderr, "Too many ledbat logs!"
        sys.exit(1)
    logfile = logfiles[0]
    if not os.path.exists( logfile ) or not os.path.isfile( logfile ):
        print >> sys.stderr, "Input file missing"
    if os.path.exists( ccfile ):
        print >> sys.stderr, "Output already present"
        sys.exit(1)
        
    fl = None
    fc = None
    
    try:
        fl = open( logfile, 'r' )
        fd = open( ccfile, 'w' )
        fd.write( "time window hints_in hints_out\n0 0\n" )
        for line in fl:
            split = line.split()
            proceed = True
            for s in split:
                try:
                    float(s)
                except:
                    proceed = False
            
            if len(split) > 6 and proceed: 
                time = int(split[0])/1000000.0
                fd.write( "{0} {1} ".format( time, str(split[7]) ) )
    
                if len(split) > 7:
                    if split[7] == '0' and len(split) == 10:
                        fd.write( "0 {0}\n".format( split[9] ) )
                    elif split[7] != '0' and len(split) > 8:
                        fd.write( "{0} 0\n".format( split[8] ) )
                    else:
                        fd.write("0 0\n")
                else:
                    fd.write("0 0\n")

    finally:
        try:
            if fd:
                fd.close()
        except Exception:
            pass
        try:
            if fl:
                fl.close()
        except Exception:
            pass


def check_single_experiment(inputDir, outputDir):
    #seeder
    if os.path.exists( os.path.join(inputDir, 'src') ):
        parse_stderr( os.path.join(inputDir, 'src'), outputDir, "seeder" )
    else:
        print >> sys.stderr, "Missing seeder stderr log!!"

    if os.path.exists( os.path.join(inputDir, 'dst', '111') ):
        leechers = [d for d in os.listdir(os.path.join(inputDir, 'dst')) if os.path.isdir(d)]
        if len(leechers) > 1:
            # TODO multiple leechers
            pass
        else:
            parse_stderr( os.path.join(inputDir, 'dst', '111'), outputDir, "leecher" )
            parse_ledbat( os.path.join(inputDir, 'dst', '111'), outputDir, "leecher" )
            parse_ledbat( os.path.join(inputDir, 'src'), outputDir, "seeder" )
            if os.environ.get("R_SCRIPTS_TO_RUN"):
                os.environ["R_SCRIPTS_TO_RUN"] = os.environ["R_SCRIPTS_TO_RUN"] + " ledbat.r requests.r"
            else:
                os.environ["R_SCRIPTS_TO_RUN"] = "ledbat.r requests.r"
    else:
        print >> sys.stderr, "Missing stderr log for first leecher!!"


# checks the current dir structure 
def check_dir(inputDir, outputDir):
    # check for single experiment
    if os.path.exists( os.path.join(inputDir, 'src') ):
        #seeder
        check_single_experiment( inputDir, outputDir)

    # TODO multiple experiments aggregate
    else:
        print >> sys.stderr, "Multiple experiments"
        pass


if __name__ == "__main__":
    if len(argv) < 3:
        print >> sys.stderr, "Usage: %s <input-directory> <output-directory>" % (argv[0])
        print >> sys.stderr, "Got:", argv

        exit(1)

    check_dir(argv[1], argv[2])