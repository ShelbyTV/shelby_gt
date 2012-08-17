#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "cvector.h"

typedef struct cvectorStruct {

   void *elements;
   unsigned int elementsAllocated;
   unsigned int elementsCount;
   unsigned int elementSize;

} cvectorStruct;

cvector cvectorAlloc(const unsigned int elementSize)
{
   cvector toReturn = (cvectorStruct *)malloc(sizeof(cvectorStruct));
   memset(toReturn, 0, sizeof(cvectorStruct));

   toReturn->elementSize = elementSize;

   return toReturn;
}

void cvectorFree(cvector vec)
{
   assert(vec);

   if (vec->elements) {
     free(vec->elements);
   }

   free(vec); 
}

unsigned int cvectorCount(const cvector vec)
{
   assert(vec);

   return vec->elementsCount;
}

unsigned int cvectorElementSize(const cvector vec)
{
   assert(vec);

   return vec->elementSize;
}

void cvectorAddElement(cvector vec, const void *element)
{
   assert(vec);
   
   if (0 == vec->elementsAllocated) {

      vec->elementsAllocated = 10;
      vec->elements = malloc(vec->elementSize * vec->elementsAllocated);
   } else if (vec->elementsCount == vec->elementsAllocated) {

      vec->elementsAllocated *= 2;
      void *tmp = malloc(vec->elementSize * vec->elementsAllocated);
      memcpy(tmp, vec->elements, vec->elementsCount * vec->elementsCount);
      free(vec->elements);
      vec->elements = tmp;
   }

   memcpy(vec->elements + (vec->elementsCount * vec->elementSize),
          element,
          vec->elementSize);

   vec->elementsCount++;
}

void *cvectorGetElement(const cvector vec, const unsigned int index)
{
   assert(vec);
   assert(index < vec->elementsCount);

   return vec->elements + (index * vec->elementSize);
}

