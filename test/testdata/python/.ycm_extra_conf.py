import os


DIR_OF_THIS_SCRIPT: str = os.path.abspath( os.path.dirname( __file__ ) )


def Settings( **kwargs: object ) -> dict[ str, str ]:
  return {
    'project_directory': DIR_OF_THIS_SCRIPT
  }
