require 'thor'

class Starter < Thor
  include Thor::Actions

  desc 'deploy', 'run deploy to deploy app to VPS Matrix demo server'
  def deploy

    ##
    # check SSH key in .vpsmatrix dir, else generate new
      # generate ~/.vpsmatrix/config
      # generate ~/.vpsmatrix/id_rsa.pub

    ## check for .vpsmatrix_config
    ## no?
      # generate .vpsmatrix_config.yml
      # ask for API KEY
      # write it to .vpsmatrix_config.yml
    ## yes?
      # read API KEY



    # detect rails? DB in (pg, mysql, sqlite, nodb)?
    # no? - do you wish us to check it?

    # send SSH key and API KEY to API app

    # -> OK
    # upload app to API, use rsync or something easy


    # -> return error message (no account, etc.)

    # run deploy on API app
    # receive DONE deploy -> show URL

  end


end