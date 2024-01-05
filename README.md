# Using Apache Flink to write to s3 using Apache Paimon

Use the docker-compose.yml file to create a MariaDB database and an Apache Flink Job and Task manager to work with.

Make sure to add your AWS credentials to the docker-compose.yml file first, so that it will be able to write to s3.

```
docker compose up -d
```

Once the containers are running, submit the job to Flink using:

```
docker exec -it jobmanager /opt/flink/bin/sql-client.sh embedded -f /opt/flink/job.sql
```

If you open your browser to `http://localhost:8081` you'll see the Flink UI with your job running, saving the data from the database to s3 using the Paimon format

The data in s3 will be in a folder named after the database, in OCR format. ( Optimized Row Columnar (ORC) file format )

```
aws s3 ls my-s3-bucket/paimon/my_database.db/myproducts/
```

Gave the following output

```
PRE bucket-0/
PRE manifest/
PRE schema/
PRE snapshot
```

The schema it stored for the products table on s3 was in JSON format:

```
{
  "id" : 0,
  "fields" : [ {
    "id" : 0,
    "name" : "id",
    "type" : "INT NOT NULL"
  }, {
    "id" : 1,
    "name" : "name",
    "type" : "STRING"
  }, {
    "id" : 2,
    "name" : "price",
    "type" : "DECIMAL(10, 2)"
  } ],
  "highestFieldId" : 2,
  "partitionKeys" : [ ],
  "primaryKeys" : [ "id" ],
  "options" : { },
  "timeMillis" : 1696694538055
}
```





