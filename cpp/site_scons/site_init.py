import os

def shelbyObjects(objectEnv, sourceFiles, middleFix = ''):
   return [objectEnv.Object(target = os.path.splitext(sourceFile)[0] + 
                                     middleFix + 
                                     objectEnv['OBJSUFFIX'], 
                            source = sourceFile) 
           for sourceFile in sourceFiles]

def shelbyLibs(libs, suffix = ''):
   return [lib + suffix for lib in libs]

def shelbyProgram(programName, programEnv, objects, libs, libpath, suffix = ''):
   program = programEnv.Program(target = programName + suffix,
                                source = objects,
                                LIBS = libs,
                                LIBPATH = libpath)
   programEnv.Default(program)
   return program

def shelbyLibrary(libraryName, libraryEnv, objects, suffix = ''):
   library = libraryEnv.Library(target = libraryName + suffix,
                                source = objects)
   libraryEnv.Default(library)
   return library

def shelbyProgramWithInstall(programName, programEnv, objects, libs, libpath, suffix = ''):
   program = shelbyProgram(programName, programEnv, objects, libs, libpath, suffix)
   programInstall = programEnv.Install('#/bin', program)
   programEnv.Default(programInstall)
   return program

def shelbySimpleApiProgram(programName, sourceFiles, dEnv, oEnv):

   debugEnv = dEnv.Clone()
   optEnv = oEnv.Clone()

   debugEnv['CPPPATH'] = optEnv['CPPPATH'] = ['#/source', '#']

   # NOTE: Unfortunately, order of these static libs matters... lib 'shelby' uses all of the
   #       other libs, so it must come first to make sure other lib inclusions aren't auto-pruned
   #       (which happens if none of their symbols were used in the original executable or previous libraries)
   
   libMongo = File('#/build/mongo-c-driver/libmongoc.a')
   libs = ['shelby', 'mrjson', 'mrbson', 'cvector']
   libPath = ['#/build/mrjson/', '#/build/mrbson/', '#/build/cvector/', '#/build/shelby/']
   
   debugLibs = shelbyLibs(libs, '-debug') + [libMongo]
   optLibs = shelbyLibs(libs) + [libMongo]
   
   debugObjects = shelbyObjects(debugEnv, sourceFiles, '-debug')
   optObjects = shelbyObjects(optEnv, sourceFiles)
   
   shelbyProgram(programName, debugEnv, debugObjects, debugLibs, libPath, '-debug')
   shelbyProgramWithInstall(programName, optEnv, optObjects, optLibs, libPath)

def shelbySimpleLibrary(libraryName, sourceFiles, cppPath, dEnv, oEnv):

   debugEnv = dEnv.Clone()
   optEnv = oEnv.Clone()

   debugEnv['CPPPATH'] = optEnv['CPPPATH'] = cppPath

   debugObjects = shelbyObjects(debugEnv, sourceFiles, '-debug')
   optObjects = shelbyObjects(optEnv, sourceFiles)
   
   shelbyLibrary(libraryName, debugEnv, debugObjects, '-debug')
   shelbyLibrary(libraryName, optEnv, optObjects)

