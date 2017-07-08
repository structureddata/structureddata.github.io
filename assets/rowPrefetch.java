/*
   NAME
     rowPrefetch.java
   DESCRIPTION
     this program takes one command line parameter: 1) prefetch batch size
   NOTES
     <other useful comments, qualifications, etc.>
   MODIFIED   (MM/DD/YYYY)
     grahn     04/28/2007 -  Creation 
     http://structureddata.org
*/


import java.sql.*;
import java.util.*;
import oracle.jdbc.*;
import oracle.jdbc.pool.OracleDataSource;


public class rowPrefetch {
	
    public static void main(String[] args) {
        try {
            Integer batchSize = new Integer(args[0]);
            int rc = 0;

            OracleDataSource ods = new OracleDataSource();

            // ods.setURL("jdbc:oracle:oci8:@orcl");
            ods.setURL("jdbc:oracle:thin:@192.168.24.132:1521:orcl");
            ods.setUser("scott");
            ods.setPassword("tiger");

            OracleConnection conn = (OracleConnection) ods.getConnection();

            conn.setAutoCommit(false);

            short seqnum = 0;
            String[] metric = new
                    String[OracleConnection.END_TO_END_STATE_INDEX_MAX];

            metric[OracleConnection.END_TO_END_ACTION_INDEX] = "myAction";
            metric[OracleConnection.END_TO_END_MODULE_INDEX] = "rowPrefetch";
            metric[OracleConnection.END_TO_END_CLIENTID_INDEX] = "myClientId";
            conn.setEndToEndMetrics(metric, seqnum);

            DatabaseMetaData meta = conn.getMetaData();

            System.out.println(
                    "JDBC driver version is " + meta.getDriverVersion());

            // Set the default row-prefetch setting for this connection 
            ((OracleConnection) conn).setDefaultRowPrefetch(batchSize); 
            
            Statement stmt = conn.createStatement(); 

            stmt.executeQuery("alter session set tracefile_identifier=EMP2");
            stmt.executeQuery("alter session set sql_trace=true");

            long start1 = System.currentTimeMillis();
            ResultSet rset = stmt.executeQuery("SELECT ename FROM emp2");

            while (rset.next()) { 
                for(int i=1; i<50; i++){
                    System.out.println(rset.getString(1));
                    rset.next();
                }
                // Pause for 120 seconds
                System.out.println("sleeping...");
                Thread.sleep(10000);
            } 

            rset.close();
            stmt.close();

            long elapsedTimeMillis1 = System.currentTimeMillis() - start1;
            // Get elapsed time in seconds
            float elapsedTimeSec1 = elapsedTimeMillis1 / 1000F;

            System.out.println("elapsed seconds: " + elapsedTimeSec1);

            conn.close();

        } catch (Exception e) {
            System.err.println("Got an exception! ");
            System.err.println(e.getMessage());
        }
    }
}
