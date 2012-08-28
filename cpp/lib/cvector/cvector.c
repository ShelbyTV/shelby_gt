#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "cvector.h"

#define TRUE 1
#define FALSE 0

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
      memcpy(tmp, vec->elements, vec->elementsCount * vec->elementSize);
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

void cvectorSwapElements(cvector vec, unsigned int one, unsigned int two)
{
   assert(vec);
   assert(one < vec->elementsCount);
   assert(two < vec->elementsCount);

   char tmp[vec->elementSize];

   memcpy(tmp,                                      // dest
          vec->elements + (one * vec->elementSize), // source
          vec->elementSize);

   memcpy(vec->elements + (one * vec->elementSize), // dest
          vec->elements + (two * vec->elementSize), // source
          vec->elementSize);

   memcpy(vec->elements + (two * vec->elementSize), // dest
          tmp,                                      // source
          vec->elementSize);
}

void cvectorSort(cvector vec, cvectorCompareElementCallback compare)
{
   if (cvectorCount(vec) <= 1) {
      return;
   }

   // simple bubble sort algorithm; not the fastest, but probably doesn't matter for our vectors
   int swappedElement;
   int count = 0;
   do {
      swappedElement = FALSE;
      for (unsigned int i = 0; i < cvectorCount(vec) - 1; i++) {
         if (compare(cvectorGetElement(vec, i), cvectorGetElement(vec, i + 1)) > 0) {
            cvectorSwapElements(vec, i, i + 1);
            swappedElement = TRUE;
         }
      }
      count++;
      assert(count <= cvectorCount(vec)); // should always be true, given compare assert above
   } while (swappedElement);
}

